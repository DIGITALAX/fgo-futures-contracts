// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

contract FGOFuturesErrors {
    error InvalidQuantity();
    error InvalidPrice();
    error InvalidAmount();
    error InsufficientBalance();
    error ContractNotActive();
    error AlreadySettled();
    error OrderNotActive();
    error Unauthorized();
    error NoPhysicalRights();
    error NotDepositor();
    error InsufficientEscrowedAmount();
    error NoRightsDeposited();
    error InvalidSettlementBotCount();
    error InvalidSettlementReward();
    error SettlementBotLacksQualifyingNFT();
    error TokenNotMinted();
    error ExceedsAvailable();
    error ContractSettled();
    error NotSeller();
    error AlreadyMinted();
    error AlreadyExists();
    error CantRemoveSelf();
    error NotTrustedSettlementBot();
    error SettlementNotReady();
    error AlreadyStaked();
    error NoStakeToWithdraw();
    error NotSettled();
    error AlreadyRegistered();
    error InsufficientStake();
    error TokensAlreadyTraded();
    error SettlementDatePassed();
    error InsufficientFuturesDuration();
}
