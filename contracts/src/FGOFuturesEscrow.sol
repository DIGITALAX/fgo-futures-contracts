// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOFuturesErrors.sol";
import "./FGOFuturesLibrary.sol";
import "./FGOFuturesAccessControl.sol";
import "./FGOFuturesContract.sol";
import "./FGOFuturesTrading.sol";
import "./interfaces/IFGOPhysicalRights.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FGOFuturesEscrow is ERC1155Holder, ReentrancyGuard {
    FGOFuturesAccessControl public accessControl;
    FGOFuturesContract public futuresContract;
    FGOFuturesTrading public tradingContract;
    string public symbol;
    string public name;

    mapping(bytes32 => FGOFuturesLibrary.EscrowedRights) private escrowedRights;
    mapping(address => mapping(uint256 => mapping(uint256 => mapping(address => bool))))
        private hasDepositedRights;

    event RightsDeposited(
        bytes32 indexed rightsKey,
        address indexed depositor,
        address childContract,
        address originalMarket,
        uint256 childId,
        uint256 orderId,
        uint256 amount
    );

    event RightsWithdrawn(
        bytes32 indexed rightsKey,
        address indexed withdrawer,
        uint256 amount
    );

    event ChildClaimedAfterSettlement(
        uint256 indexed contractId,
        address indexed claimer,
        uint256 quantity,
        uint256 childId
    );

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _;
    }

    modifier onlyFuturesContract() {
        if (msg.sender != address(futuresContract)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _;
    }

    constructor(address _accessControl) {
        accessControl = FGOFuturesAccessControl(_accessControl);

        symbol = "FGOE";
        name = "FGOFuturesEscrow";
    }

    function depositPhysicalRights(
        uint256 childId,
        uint256 orderId,
        uint256 amount,
        address originalMarket,
        address childContract
    ) external nonReentrant returns (bytes32 rightsKey) {
        if (amount == 0) revert FGOFuturesErrors.InvalidAmount();

        if (
            !IFGOChild(childContract).getIsPhysicalRightsHolder(
                childId,
                orderId,
                address(this),
                originalMarket
            )
        ) {
            revert FGOFuturesErrors.NoPhysicalRights();
        }

        if (
            IFGOMarket(originalMarket).getOrderReceipt(orderId).buyer !=
            msg.sender
        ) {
            revert FGOFuturesErrors.NoPhysicalRights();
        }

        rightsKey = keccak256(
            abi.encodePacked(
                childId,
                childContract,
                orderId,
                originalMarket,
                msg.sender
            )
        );

        if (escrowedRights[rightsKey].amount == 0) {
            escrowedRights[rightsKey] = FGOFuturesLibrary.EscrowedRights({
                childId: childId,
                orderId: orderId,
                amount: amount,
                amountUsedForFutures: 0,
                depositedAt: block.timestamp,
                childContract: childContract,
                originalMarket: originalMarket,
                depositor: msg.sender,
                futuresCreated: false
            });
        } else {
            escrowedRights[rightsKey].amount += amount;
        }

        hasDepositedRights[childContract][childId][orderId][
            originalMarket
        ] = true;

        emit RightsDeposited(
            rightsKey,
            msg.sender,
            childContract,
            originalMarket,
            childId,
            orderId,
            amount
        );
    }

    function withdrawPhysicalRights(
        uint256 childId,
        uint256 orderId,
        uint256 amount,
        address childContract,
        address originalMarket
    ) external nonReentrant {
        bytes32 rightsKey = keccak256(
            abi.encodePacked(
                childId,
                childContract,
                orderId,
                originalMarket,
                msg.sender
            )
        );
        FGOFuturesLibrary.EscrowedRights storage rights = escrowedRights[
            rightsKey
        ];

        if (rights.depositor != msg.sender)
            revert FGOFuturesErrors.NotDepositor();

        uint256 availableAmount = rights.amount - rights.amountUsedForFutures;
        if (amount > availableAmount)
            revert FGOFuturesErrors.InsufficientEscrowedAmount();

        rights.amount -= amount;

        IFGOChild(rights.childContract).transferPhysicalRights(
            rights.childId,
            rights.orderId,
            amount,
            msg.sender,
            originalMarket
        );

        emit RightsWithdrawn(rightsKey, msg.sender, amount);
    }

    function getEscrowedRights(
        uint256 childId,
        uint256 orderId,
        address childContract,
        address originalMarket,
        address depositor
    ) external view returns (FGOFuturesLibrary.EscrowedRights memory) {
        bytes32 rightsKey = keccak256(
            abi.encodePacked(
                childId,
                childContract,
                orderId,
                originalMarket,
                depositor
            )
        );
        return escrowedRights[rightsKey];
    }

    function getEscrowedRights(
        bytes32 rightsKey
    ) external view returns (FGOFuturesLibrary.EscrowedRights memory) {
        return escrowedRights[rightsKey];
    }

    function hasDepositedRightsForMarket(
        address childContract,
        uint256 childId,
        uint256 orderId,
        address market
    ) external view returns (bool) {
        return hasDepositedRights[childContract][childId][orderId][market];
    }

    function markRightsAsUsed(
        bytes32 rightsKey,
        uint256 amountUsed
    ) external onlyFuturesContract {
        escrowedRights[rightsKey].amountUsedForFutures += amountUsed;
        escrowedRights[rightsKey].futuresCreated = true;
    }

    function setFuturesContract(address _futuresContract) external onlyAdmin {
        futuresContract = FGOFuturesContract(_futuresContract);
    }

    function setTradingContract(address _tradingContract) external onlyAdmin {
        tradingContract = FGOFuturesTrading(_tradingContract);
    }

    function claimChildAfterSettlement(uint256 contractId) external {
        FGOFuturesLibrary.FuturesContract memory fc = futuresContract.getFuturesContract(contractId);
        
        if (!fc.isSettled) revert FGOFuturesErrors.NotSettled();
        
        uint256 userBalance = tradingContract.balanceOf(msg.sender, fc.tokenId);
        if (userBalance == 0) revert FGOFuturesErrors.InsufficientBalance();
        
        bytes32 rightsKey = futuresContract.getContractIdToRightsKey(contractId);
        FGOFuturesLibrary.EscrowedRights storage rights = escrowedRights[rightsKey];
        
        if (rights.amount < userBalance) revert FGOFuturesErrors.InsufficientEscrowedAmount();
        
        tradingContract.burn(msg.sender, fc.tokenId, userBalance);
        
        IERC1155(rights.childContract).safeTransferFrom(
            address(this),
            msg.sender,
            rights.childId,
            userBalance,
            ""
        );
        
        rights.amount -= userBalance;
        
        emit ChildClaimedAfterSettlement(contractId, msg.sender, userBalance, rights.childId);
    }

    function getAvailableAmount(
        uint256 childId,
        uint256 orderId,
        address childContract,
        address originalMarket
    ) external view returns (uint256) {
        bytes32 rightsKey = keccak256(
            abi.encodePacked(
                childId,
                childContract,
                orderId,
                originalMarket,
                msg.sender
            )
        );
        FGOFuturesLibrary.EscrowedRights memory rights = escrowedRights[
            rightsKey
        ];
        return rights.amount - rights.amountUsedForFutures;
    }
}
