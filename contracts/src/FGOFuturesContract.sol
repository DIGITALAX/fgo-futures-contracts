// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOFuturesErrors.sol";
import "./FGOFuturesLibrary.sol";
import "./FGOFuturesAccessControl.sol";
import "./FGOFuturesEscrow.sol";
import "./FGOFuturesSettlement.sol";
import "./FGOFuturesTrading.sol";
import "./interfaces/IFGOPhysicalRights.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FGOFuturesContract is ReentrancyGuard {
    FGOFuturesAccessControl public accessControl;
    FGOFuturesEscrow public escrow;
    FGOFuturesSettlement public settlementContract;
    FGOFuturesTrading public tradingContract;
    string public symbol;
    string public name;

    uint256 public constant MIN_Settlement_REWARD_BPS = 100;
    uint256 public constant MAX_Settlement_REWARD_BPS = 300;
    uint256 public constant MIN_FUTURES_DURATION = 1 hours;

    uint256 private contractCount;
    mapping(uint256 => FGOFuturesLibrary.FuturesContract)
        private futuresContracts;
    mapping(uint256 => bytes32) private contractIdToRightsKey;
    mapping(uint256 => uint256) private tokenIdToContractId;
    mapping(address => bool) private isValidERC721;
    address[] public validERC721Tokens;

    event FuturesContractOpened(
        uint256 indexed contractId,
        uint256 childId,
        uint256 orderId,
        uint256 quantity,
        uint256 pricePerUnit,
        address childContract,
        address originalMarket,
        address originalHolder
    );

    event FuturesContractCancelled(
        uint256 indexed contractId,
        address originalHolder
    );

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _;
    }

    modifier onlySettlementContract() {
        if (msg.sender != address(settlementContract)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _;
    }

    constructor(
        address _accessControl,
        address _escrow,
        address[] memory _validERC721Tokens
    ) {
        accessControl = FGOFuturesAccessControl(_accessControl);
        escrow = FGOFuturesEscrow(_escrow);

        symbol = "FGOFC";
        name = "FGOFuturesContract";

        for (uint256 i = 0; i < _validERC721Tokens.length; i++) {
            if (!isValidERC721[_validERC721Tokens[i]]) {
                validERC721Tokens.push(_validERC721Tokens[i]);
                isValidERC721[_validERC721Tokens[i]] = true;
            }
        }
    }

    function openFuturesContract(
        uint256 childId,
        uint256 orderId,
        uint256 amount,
        uint256 pricePerUnit,
        uint256 settlementRewardBPS,
        address childContract,
        address originalMarket,
        address[] memory trustedSettlementBots,
        string memory uri
    ) external nonReentrant returns (uint256 contractId) {
        bytes32 rightsKey = keccak256(
            abi.encodePacked(
                childId,
                childContract,
                orderId,
                originalMarket,
                msg.sender
            )
        );
        FGOFuturesLibrary.EscrowedRights memory rights = escrow
            .getEscrowedRights(rightsKey);

        (uint256 tokenId, uint256 futuresSettlementDate) = _validateRights(
            rights,
            amount,
            pricePerUnit,
            settlementRewardBPS,
            trustedSettlementBots
        );

        if (tokenIdToContractId[tokenId] != 0) {
            contractId = tokenIdToContractId[tokenId];
            futuresContracts[contractId].quantity += amount;
            tradingContract.mint(tokenId, amount, msg.sender, "");
            tradingContract.updateSellOrderQuantity(tokenId, amount);
        } else {
            contractCount++;
            contractId = contractCount;

            futuresContracts[contractId] = FGOFuturesLibrary.FuturesContract({
                childId: rights.childId,
                orderId: rights.orderId,
                quantity: amount,
                pricePerUnit: pricePerUnit,
                settlementRewardBPS: settlementRewardBPS,
                tokenId: tokenId,
                createdAt: block.timestamp,
                settledAt: 0,
                futuresSettlementDate: futuresSettlementDate,
                childContract: rights.childContract,
                originalMarket: rights.originalMarket,
                originalHolder: msg.sender,
                isActive: true,
                isSettled: false,
                uri: uri,
                trustedSettlementBots: trustedSettlementBots
            });

            contractIdToRightsKey[contractId] = rightsKey;
            tokenIdToContractId[tokenId] = contractId;

            tradingContract.mint(tokenId, amount, msg.sender, uri);

            uint256 sellOrderId = tradingContract.createSellOrderFromContract(
                tokenId,
                amount,
                pricePerUnit,
                msg.sender
            );
            tradingContract.setInitialSellOrderId(tokenId, sellOrderId);
        }

        escrow.markRightsAsUsed(rightsKey, amount);

        emit FuturesContractOpened(
            contractId,
            rights.childId,
            rights.orderId,
            amount,
            pricePerUnit,
            rights.childContract,
            rights.originalMarket,
            msg.sender
        );
    }

    function _validateRights(
        FGOFuturesLibrary.EscrowedRights memory rights,
        uint256 amount,
        uint256 pricePerUnit,
        uint256 settlementRewardBPS,
        address[] memory trustedSettlementBots
    ) internal view returns (uint256, uint256) {
        if (rights.depositor != msg.sender)
            revert FGOFuturesErrors.NotDepositor();
        if (rights.amount == 0) revert FGOFuturesErrors.NoRightsDeposited();

        uint256 availableAmount = rights.amount - rights.amountUsedForFutures;
        if (amount > availableAmount)
            revert FGOFuturesErrors.InsufficientEscrowedAmount();
        if (amount == 0) revert FGOFuturesErrors.InvalidAmount();
        if (pricePerUnit == 0) revert FGOFuturesErrors.InvalidPrice();
        if (
            trustedSettlementBots.length < 3 || trustedSettlementBots.length > 5
        ) revert FGOFuturesErrors.InvalidSettlementBotCount();
        if (
            settlementRewardBPS < MIN_Settlement_REWARD_BPS ||
            settlementRewardBPS > MAX_Settlement_REWARD_BPS
        ) revert FGOFuturesErrors.InvalidSettlementReward();

        for (uint256 i = 0; i < trustedSettlementBots.length; i++) {
            FGOFuturesLibrary.SettlementBot memory bot = settlementContract
                .getSettlementBot(trustedSettlementBots[i]);
            if (bot.botAddress == address(0)) {
                revert FGOFuturesErrors.Unauthorized();
            }
            if (
                !settlementContract.hasQualifyingNFT(trustedSettlementBots[i])
            ) {
                revert FGOFuturesErrors.SettlementBotLacksQualifyingNFT();
            }
        }

        FGOMarketLibrary.OrderReceipt memory orderReceipt = IFGOMarket(
            rights.originalMarket
        ).getOrderReceipt(rights.orderId);
        uint256 futuresSettlementDate = orderReceipt.timestamp +
            rights.estimatedDeliveryDuration;

        if (futuresSettlementDate <= block.timestamp)
            revert FGOFuturesErrors.SettlementDatePassed();
        if (futuresSettlementDate - block.timestamp < MIN_FUTURES_DURATION)
            revert FGOFuturesErrors.InsufficientFuturesDuration();

        uint256 tokenId = _calculateTokenId(
            rights.childId,
            rights.orderId,
            rights.childContract,
            rights.originalMarket,
            pricePerUnit
        );

        return (tokenId, futuresSettlementDate);
    }

    function _calculateTokenId(
        uint256 childId,
        uint256 orderId,
        address childContract,
        address marketContract,
        uint256 pricePerUnit
    ) internal pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        childContract,
                        childId,
                        orderId,
                        marketContract,
                        pricePerUnit
                    )
                )
            );
    }

    function getFuturesContract(
        uint256 contractId
    ) external view returns (FGOFuturesLibrary.FuturesContract memory) {
        return futuresContracts[contractId];
    }

    function getContractIdToRightsKey(
        uint256 contractId
    ) external view returns (bytes32) {
        return contractIdToRightsKey[contractId];
    }

    function addValidERC721Token(address token) external onlyAdmin {
        if (!isValidERC721[token]) {
            validERC721Tokens.push(token);
            isValidERC721[token] = true;
        }
    }

    function removeValidERC721Token(address token) external onlyAdmin {
        if (isValidERC721[token]) {
            isValidERC721[token] = false;
            for (uint256 i = 0; i < validERC721Tokens.length; i++) {
                if (validERC721Tokens[i] == token) {
                    validERC721Tokens[i] = validERC721Tokens[
                        validERC721Tokens.length - 1
                    ];
                    validERC721Tokens.pop();
                    break;
                }
            }
        }
    }

    function getContractCount() public view returns (uint256) {
        return contractCount;
    }

    function getValidERC721Tokens() public view returns (address[] memory) {
        return validERC721Tokens;
    }

    function isValidERC721Token(address token) public view returns (bool) {
        return isValidERC721[token];
    }

    function settleFuturesContract(
        uint256 contractId
    ) external onlySettlementContract {
        if (futuresContracts[contractId].isSettled) {
            revert FGOFuturesErrors.AlreadySettled();
        }

        futuresContracts[contractId].isSettled = true;
        futuresContracts[contractId].settledAt = block.timestamp;
        futuresContracts[contractId].isActive = false;
    }

    function cancelFuturesContract(uint256 contractId) external nonReentrant {
        FGOFuturesLibrary.FuturesContract storage fc = futuresContracts[
            contractId
        ];

        if (fc.originalHolder != msg.sender)
            revert FGOFuturesErrors.Unauthorized();
        if (!fc.isActive) revert FGOFuturesErrors.ContractNotActive();
        if (fc.isSettled) revert FGOFuturesErrors.AlreadySettled();

        uint256 originalHolderBalance = tradingContract.balanceOf(
            msg.sender,
            fc.tokenId
        );
        if (originalHolderBalance != fc.quantity)
            revert FGOFuturesErrors.TokensAlreadyTraded();

        bytes32 rightsKey = contractIdToRightsKey[contractId];
        escrow.markRightsAsUnused(rightsKey, fc.quantity);

        tradingContract.burn(msg.sender, fc.tokenId, fc.quantity);

        fc.isActive = false;

        emit FuturesContractCancelled(contractId, msg.sender);
    }

    function setSettlementContract(
        address _settlementContract
    ) external onlyAdmin {
        settlementContract = FGOFuturesSettlement(_settlementContract);
    }

    function setTradingContract(address _tradingContract) external onlyAdmin {
        tradingContract = FGOFuturesTrading(_tradingContract);
    }

    function getContractByToken(
        uint256 tokenId
    ) external view returns (uint256) {
        return tokenIdToContractId[tokenId];
    }
}
