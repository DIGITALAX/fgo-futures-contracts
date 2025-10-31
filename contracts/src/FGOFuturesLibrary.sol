// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

contract FGOFuturesLibrary {
    struct EscrowedRights {
        uint256 childId;
        uint256 orderId;
        uint256 amount;
        uint256 amountUsedForFutures;
        uint256 depositedAt;
        uint256 estimatedDeliveryDuration;
        address childContract;
        address originalMarket;
        address depositor;
        bool futuresCreated;
    }

    struct FuturesContract {
        uint256 childId;
        uint256 orderId;
        uint256 quantity;
        uint256 pricePerUnit;
        uint256 settlementRewardBPS;
        uint256 tokenId;
        uint256 createdAt;
        uint256 settledAt;
        uint256 futuresSettlementDate;
        address childContract;
        address originalMarket;
        address originalHolder;
        bool isActive;
        bool isSettled;
        address[] trustedSettlementBots;
        string uri;
    }

    struct SellOrder {
        uint256 tokenId;
        uint256 quantity;
        uint256 pricePerUnit;
        uint256 filled;
        uint256 createdAt;
        address seller;
        bool isActive;
    }

    struct SettlementBot {
        uint256 totalSettlements;
        uint256 averageDelaySeconds;
        uint256 monaStaked;
        uint256 slashEvents;
        address botAddress;
    }

    struct SettlementMetrics {
        uint256 settlementTime;
        uint256 delay;
        uint256 reward;
        address settlementBot;
    }
}
