// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOFuturesErrors.sol";
import "./FGOFuturesLibrary.sol";
import "./FGOFuturesAccessControl.sol";
import "./FGOFuturesEscrow.sol";
import "./FGOFuturesMEV.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FGOFuturesContract is ReentrancyGuard {
    FGOFuturesAccessControl public accessControl;
    FGOFuturesEscrow public escrow;
    FGOFuturesMEV public mevContract;
    string public symbol;
    string public name;

    uint256 public constant MIN_MEV_REWARD_BPS = 100;
    uint256 public constant MAX_MEV_REWARD_BPS = 300;

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

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _;
    }

    modifier onlyMEVContract() {
        if (msg.sender != address(mevContract)) {
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
        uint256 mevRewardBPS,
        address childContract,
        address originalMarket,
        address[] calldata trustedMEVBots
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
            .getEscrowedRights(
                childId,
                orderId,
                childContract,
                originalMarket,
                msg.sender
            );

        if (rights.depositor != msg.sender)
            revert FGOFuturesErrors.NotDepositor();
        if (rights.amount == 0) revert FGOFuturesErrors.NoRightsDeposited();

        uint256 availableAmount = rights.amount - rights.amountUsedForFutures;
        if (amount > availableAmount)
            revert FGOFuturesErrors.InsufficientEscrowedAmount();
        if (amount == 0) revert FGOFuturesErrors.InvalidAmount();
        if (pricePerUnit == 0) revert FGOFuturesErrors.InvalidPrice();
        if (trustedMEVBots.length < 3 || trustedMEVBots.length > 5)
            revert FGOFuturesErrors.InvalidMEVBotCount();
        if (
            mevRewardBPS < MIN_MEV_REWARD_BPS ||
            mevRewardBPS > MAX_MEV_REWARD_BPS
        ) revert FGOFuturesErrors.InvalidMEVReward();

        for (uint256 i = 0; i < trustedMEVBots.length; i++) {
            FGOFuturesLibrary.MEVBot memory bot = mevContract.getMEVBot(
                trustedMEVBots[i]
            );
            if (bot.botAddress == address(0)) {
                revert FGOFuturesErrors.Unauthorized();
            }
            if (!mevContract.hasQualifyingNFT(trustedMEVBots[i])) {
                revert FGOFuturesErrors.MEVBotLacksQualifyingNFT();
            }
        }

        uint256 tokenId = _calculateTokenId(
            rights.childId,
            rights.orderId,
            rights.childContract,
            rights.originalMarket,
            pricePerUnit
        );

        if (tokenIdToContractId[tokenId] != 0) {
            contractId = tokenIdToContractId[tokenId];
            futuresContracts[contractId].quantity += amount;
        } else {
            contractId = contractCount++;

            futuresContracts[contractId] = FGOFuturesLibrary.FuturesContract({
                childId: rights.childId,
                orderId: rights.orderId,
                quantity: amount,
                pricePerUnit: pricePerUnit,
                mevRewardBPS: mevRewardBPS,
                tokenId: tokenId,
                createdAt: block.timestamp,
                settledAt: 0,
                childContract: rights.childContract,
                originalMarket: rights.originalMarket,
                originalHolder: msg.sender,
                isActive: true,
                isSettled: false,
                trustedMEVBots: trustedMEVBots
            });

            contractIdToRightsKey[contractId] = rightsKey;
            tokenIdToContractId[tokenId] = contractId;
        }

        escrow.markRightsAsUsed(rightsKey, amount);

        emit FuturesContractOpened(
            contractId,
            rights.childId,
            rights.orderId,
            rights.amount,
            pricePerUnit,
            rights.childContract,
            rights.originalMarket,
            msg.sender
        );
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
    ) external onlyMEVContract {
        if (futuresContracts[contractId].isSettled) {
            revert FGOFuturesErrors.AlreadySettled();
        }

        futuresContracts[contractId].isSettled = true;
        futuresContracts[contractId].settledAt = block.timestamp;
    }

    function setMEVContract(address _mevContract) external onlyAdmin {
        mevContract = FGOFuturesMEV(_mevContract);
    }
}
