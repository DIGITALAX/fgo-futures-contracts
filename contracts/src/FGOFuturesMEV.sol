// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOFuturesErrors.sol";
import "./FGOFuturesLibrary.sol";
import "./FGOFuturesAccessControl.sol";
import "./FGOFuturesContract.sol";
import "./FGOFuturesEscrow.sol";
import "./FGOFuturesTrading.sol";
import "./interfaces/IFGOPhysicalRights.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FGOFuturesMEV is ReentrancyGuard {
    FGOFuturesAccessControl public accessControl;
    FGOFuturesContract public futuresContract;
    FGOFuturesEscrow public escrow;
    FGOFuturesTrading public trading;
    string public symbol;
    string public name;

    uint256 public constant BASIS_POINTS = 10000;
    uint256 private minStakeAmount;
    uint256 private maxSettlementDelay;
    uint256 private slashPercentageBPS;

    mapping(address => FGOFuturesLibrary.MEVBot) private mevBots;
    mapping(uint256 => FGOFuturesLibrary.SettlementMetrics) private settlements;
    mapping(uint256 => bool) private contractSettled;
    mapping(address => uint256) private stakedAmount;

    event MEVBotRegistered(uint256 stakeAmount, address bot);
    event MEVBotSlashed(uint256 slashAmount, address bot);
    event ContractSettled(
        uint256 indexed contractId,
        uint256 reward,
        uint256 actualCompletionTime,
        address mevBot
    );
    event StakeWithdrawn(uint256 amount, address bot);

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _;
    }

    modifier onlyTrustedMEVBot(uint256 contractId) {
        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);
        bool isTrusted = false;
        for (uint256 i = 0; i < fc.trustedMEVBots.length; i++) {
            if (fc.trustedMEVBots[i] == msg.sender) {
                isTrusted = true;
                break;
            }
        }
        if (!isTrusted) revert FGOFuturesErrors.NotTrustedMEVBot();
        if (!hasQualifyingNFT(msg.sender)) {
            revert FGOFuturesErrors.MEVBotLacksQualifyingNFT();
        }
        _;
    }

    modifier requiresQualifyingNFT() {
        if (!hasQualifyingNFT(msg.sender)) {
            revert FGOFuturesErrors.MEVBotLacksQualifyingNFT();
        }
        _;
    }

    constructor(
        address _accessControl,
        address _futuresContract,
        address _escrow,
        address _trading,
        uint256 _minStakeAmount,
        uint256 _maxSettlementDelay,
        uint256 _slashPercentageBPS
    ) {
        accessControl = FGOFuturesAccessControl(_accessControl);
        futuresContract = FGOFuturesContract(_futuresContract);
        escrow = FGOFuturesEscrow(_escrow);
        trading = FGOFuturesTrading(_trading);
        minStakeAmount = _minStakeAmount;
        maxSettlementDelay = _maxSettlementDelay;
        slashPercentageBPS = _slashPercentageBPS;
        symbol = "FGOMEV";
        name = "FGOFuturesMEV";
    }

    function registerMEVBot() external nonReentrant requiresQualifyingNFT {
        uint256 currentStake = stakedAmount[msg.sender];

        if (currentStake >= minStakeAmount) {
            return;
        }

        uint256 stakeNeeded = minStakeAmount - currentStake;

        address monaToken = accessControl.monaToken();
        IERC20(monaToken).transferFrom(msg.sender, address(this), stakeNeeded);

        stakedAmount[msg.sender] = minStakeAmount;

        if (mevBots[msg.sender].botAddress == address(0)) {
            mevBots[msg.sender] = FGOFuturesLibrary.MEVBot({
                totalSettlements: 0,
                averageDelaySeconds: 0,
                monaStaked: minStakeAmount,
                slashEvents: 0,
                botAddress: msg.sender
            });
        } else {
            mevBots[msg.sender].monaStaked = minStakeAmount;
        }

        emit MEVBotRegistered(minStakeAmount, msg.sender);
    }

    function settleFuturesContract(
        uint256 contractId
    ) external nonReentrant onlyTrustedMEVBot(contractId) {
        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);

        if (fc.isSettled) revert FGOFuturesErrors.AlreadySettled();
        if (!fc.isActive) revert FGOFuturesErrors.ContractNotActive();
        if (contractSettled[contractId])
            revert FGOFuturesErrors.AlreadySettled();

        address fulfillment = IFGOMarket(fc.originalMarket).fulfillment();

        FGOMarketLibrary.FulfillmentStatus memory status = IFGOFulfillment(
            fulfillment
        ).getFulfillmentStatus(fc.orderId);

        if (status.currentStep != status.steps.length)
            revert FGOFuturesErrors.SettlementNotReady();

        uint256 actualCompletionTime = status.lastUpdated;
        uint256 settlementDelay = block.timestamp - actualCompletionTime;
        address monaToken = accessControl.monaToken();

        if (settlementDelay > maxSettlementDelay) {
            uint256 slashAmount = (stakedAmount[msg.sender] *
                slashPercentageBPS) / BASIS_POINTS;
            stakedAmount[msg.sender] -= slashAmount;
            mevBots[msg.sender].slashEvents++;
            mevBots[msg.sender].monaStaked = stakedAmount[msg.sender];

            IERC20(monaToken).transfer(fc.originalHolder, slashAmount);

            emit MEVBotSlashed(slashAmount, msg.sender);
        }

        uint256 totalReward = (fc.pricePerUnit *
            fc.quantity *
            fc.mevRewardBPS) / BASIS_POINTS;

        IERC20(monaToken).transferFrom(
            fc.originalHolder,
            msg.sender,
            totalReward
        );

        contractSettled[contractId] = true;

        futuresContract.settleFuturesContract(contractId);

        settlements[contractId] = FGOFuturesLibrary.SettlementMetrics({
            actualCompletionTime: actualCompletionTime,
            settlementTime: block.timestamp,
            delay: settlementDelay,
            reward: totalReward,
            mevBot: msg.sender
        });

        mevBots[msg.sender].totalSettlements++;
        uint256 oldAverage = mevBots[msg.sender].averageDelaySeconds;
        uint256 newAverage = (oldAverage *
            (mevBots[msg.sender].totalSettlements - 1) +
            settlementDelay) / mevBots[msg.sender].totalSettlements;
        mevBots[msg.sender].averageDelaySeconds = newAverage;

        emit ContractSettled(
            contractId,
            totalReward,
            actualCompletionTime,
            msg.sender
        );
    }

    function withdrawStake() external nonReentrant {
        uint256 amount = stakedAmount[msg.sender];
        if (amount == 0) revert FGOFuturesErrors.NoStakeToWithdraw();

        stakedAmount[msg.sender] = 0;
        mevBots[msg.sender].monaStaked = 0;

        address monaToken = accessControl.monaToken();
        IERC20(monaToken).transfer(msg.sender, amount);

        emit StakeWithdrawn(amount, msg.sender);
    }

    function getMEVBot(
        address bot
    ) external view returns (FGOFuturesLibrary.MEVBot memory) {
        return mevBots[bot];
    }

    function getSettlementMetrics(
        uint256 contractId
    ) external view returns (FGOFuturesLibrary.SettlementMetrics memory) {
        return settlements[contractId];
    }

    function isContractSettled(
        uint256 contractId
    ) external view returns (bool) {
        return contractSettled[contractId];
    }

    function getStakedAmount(address bot) external view returns (uint256) {
        return stakedAmount[bot];
    }

    function updateMEVParameters(
        uint256 _minStakeAmount,
        uint256 _maxSettlementDelay,
        uint256 _slashPercentageBPS
    ) external onlyAdmin {
        minStakeAmount = _minStakeAmount;
        maxSettlementDelay = _maxSettlementDelay;
        slashPercentageBPS = _slashPercentageBPS;
    }

    function getMinStakeAmount() external view returns (uint256) {
        return minStakeAmount;
    }

    function getMaxSettlementDelay() external view returns (uint256) {
        return maxSettlementDelay;
    }

    function getSlashPercentageBPS() external view returns (uint256) {
        return slashPercentageBPS;
    }

    function hasQualifyingNFT(address bot) public view returns (bool) {
        address[] memory validTokens = futuresContract.getValidERC721Tokens();
        for (uint256 i = 0; i < validTokens.length; i++) {
            if (IERC721(validTokens[i]).balanceOf(bot) > 0) {
                return true;
            }
        }
        return false;
    }

    function updateMEVBotStake() external nonReentrant requiresQualifyingNFT {
        if (mevBots[msg.sender].botAddress == address(0)) {
            revert FGOFuturesErrors.Unauthorized();
        }

        uint256 currentStake = stakedAmount[msg.sender];

        if (currentStake >= minStakeAmount) {
            return;
        }

        uint256 stakeNeeded = minStakeAmount - currentStake;

        address monaToken = accessControl.monaToken();
        IERC20(monaToken).transferFrom(msg.sender, address(this), stakeNeeded);

        stakedAmount[msg.sender] = minStakeAmount;
        mevBots[msg.sender].monaStaked = minStakeAmount;

        emit MEVBotRegistered(minStakeAmount, msg.sender);
    }
}
