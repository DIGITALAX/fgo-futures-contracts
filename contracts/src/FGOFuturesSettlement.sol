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

contract FGOFuturesSettlement is ReentrancyGuard {
    FGOFuturesAccessControl public accessControl;
    FGOFuturesContract public futuresContract;
    FGOFuturesEscrow public escrow;
    FGOFuturesTrading public trading;
    string public symbol;
    string public name;

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_STAKE_MULTIPLIER_BPS = 15000;
    uint256 private minStakeAmount;
    uint256 private maxSettlementDelay;
    uint256 private slashPercentageBPS;

    mapping(address => FGOFuturesLibrary.SettlementBot) private settlementBots;
    mapping(uint256 => FGOFuturesLibrary.SettlementMetrics) private settlements;
    mapping(uint256 => bool) private contractSettled;

    event SettlementBotRegistered(uint256 stakeAmount, address bot);
    event SettlementBotSlashed(uint256 slashAmount, address bot);
    event ContractSettled(
        uint256 indexed contractId,
        uint256 reward,
        uint256 futuresSettlementDate,
        address settlementBot
    );
    event EmergencySettlement(
        uint256 indexed contractId,
        address settler,
        uint256 settlementTime
    );
    event StakeWithdrawn(uint256 amount, address bot);
    event StakeIncreased(uint256 totalStake, address bot);

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _;
    }

    modifier onlyTrustedSettlementBot(uint256 contractId) {
        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);
        bool isTrusted = false;
        for (uint256 i = 0; i < fc.trustedSettlementBots.length; i++) {
            if (fc.trustedSettlementBots[i] == msg.sender) {
                isTrusted = true;
                break;
            }
        }
        if (!isTrusted) revert FGOFuturesErrors.NotTrustedSettlementBot();
        if (!hasQualifyingNFT(msg.sender)) {
            revert FGOFuturesErrors.SettlementBotLacksQualifyingNFT();
        }
        if (settlementBots[msg.sender].monaStaked < minStakeAmount) {
            revert FGOFuturesErrors.InsufficientStake();
        }
        _;
    }

    modifier requiresQualifyingNFT() {
        if (!hasQualifyingNFT(msg.sender)) {
            revert FGOFuturesErrors.SettlementBotLacksQualifyingNFT();
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
        symbol = "FGOSET";
        name = "FGOFuturesSettlement";
    }

    function registerSettlementBot(
        uint256 stakeAmount
    ) external nonReentrant requiresQualifyingNFT {
        if (stakeAmount < minStakeAmount)
            revert FGOFuturesErrors.InvalidAmount();

        uint256 currentStake = settlementBots[msg.sender].monaStaked;
        if (currentStake > 0) revert FGOFuturesErrors.AlreadyRegistered();

        address monaToken = accessControl.monaToken();
        IERC20(monaToken).transferFrom(msg.sender, address(this), stakeAmount);

        settlementBots[msg.sender] = FGOFuturesLibrary.SettlementBot({
            totalSettlements: 0,
            averageDelaySeconds: 0,
            monaStaked: stakeAmount,
            slashEvents: 0,
            botAddress: msg.sender
        });

        emit SettlementBotRegistered(stakeAmount, msg.sender);
    }

    function settleFuturesContract(
        uint256 contractId
    ) external nonReentrant onlyTrustedSettlementBot(contractId) {
        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);

        if (fc.isSettled) revert FGOFuturesErrors.AlreadySettled();
        if (!fc.isActive) revert FGOFuturesErrors.ContractNotActive();
        if (contractSettled[contractId])
            revert FGOFuturesErrors.AlreadySettled();

        if (block.timestamp < fc.futuresSettlementDate)
            revert FGOFuturesErrors.SettlementNotReady();

        uint256 settlementDelay = block.timestamp - fc.futuresSettlementDate;
        address monaToken = accessControl.monaToken();

        if (settlementDelay > maxSettlementDelay) {
            uint256 slashAmount = (settlementBots[msg.sender].monaStaked *
                slashPercentageBPS) / BASIS_POINTS;
            settlementBots[msg.sender].monaStaked -= slashAmount;
            settlementBots[msg.sender].slashEvents++;

            IERC20(monaToken).transfer(fc.originalHolder, slashAmount);

            emit SettlementBotSlashed(slashAmount, msg.sender);
        }

        uint256 baseReward = (fc.pricePerUnit * fc.quantity * fc.settlementRewardBPS) /
            BASIS_POINTS;

        uint256 stakeMultiplier = _calculateStakeMultiplier(msg.sender);
        uint256 totalReward = (baseReward * stakeMultiplier) / BASIS_POINTS;

        IERC20(monaToken).transferFrom(
            fc.originalHolder,
            msg.sender,
            totalReward
        );

        contractSettled[contractId] = true;

        futuresContract.settleFuturesContract(contractId);

        settlements[contractId] = FGOFuturesLibrary.SettlementMetrics({
            settlementTime: block.timestamp,
            delay: settlementDelay,
            reward: totalReward,
            settlementBot: msg.sender
        });

        settlementBots[msg.sender].totalSettlements++;
        uint256 oldAverage = settlementBots[msg.sender].averageDelaySeconds;
        uint256 newAverage = (oldAverage *
            (settlementBots[msg.sender].totalSettlements - 1) +
            settlementDelay) / settlementBots[msg.sender].totalSettlements;
        settlementBots[msg.sender].averageDelaySeconds = newAverage;

        emit ContractSettled(
            contractId,
            totalReward,
            fc.futuresSettlementDate,
            msg.sender
        );
    }

    function withdrawStake() external nonReentrant {
        uint256 amount = settlementBots[msg.sender].monaStaked;
        if (amount == 0) revert FGOFuturesErrors.NoStakeToWithdraw();

        settlementBots[msg.sender].monaStaked = 0;

        address monaToken = accessControl.monaToken();
        IERC20(monaToken).transfer(msg.sender, amount);

        emit StakeWithdrawn(amount, msg.sender);
    }

    function emergencySettleFuturesContract(
        uint256 contractId
    ) external nonReentrant {
        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);

        if (fc.isSettled) revert FGOFuturesErrors.AlreadySettled();
        if (!fc.isActive) revert FGOFuturesErrors.ContractNotActive();
        if (contractSettled[contractId])
            revert FGOFuturesErrors.AlreadySettled();

        bool isOriginalHolder = (msg.sender == fc.originalHolder);
        bool isFuturesHolder = false;

        if (trading.isTokenMinted(fc.tokenId)) {
            isFuturesHolder = trading.balanceOf(msg.sender, fc.tokenId) > 0;
        }

        if (!isOriginalHolder && !isFuturesHolder) {
            revert FGOFuturesErrors.Unauthorized();
        }

        if (block.timestamp < fc.futuresSettlementDate)
            revert FGOFuturesErrors.SettlementNotReady();

        uint256 timeSinceSettlementDate = block.timestamp - fc.futuresSettlementDate;

        if (timeSinceSettlementDate <= maxSettlementDelay)
            revert FGOFuturesErrors.SettlementNotReady();

        bool anyBotCanSettle = false;
        for (uint256 i = 0; i < fc.trustedSettlementBots.length; i++) {
            if (hasQualifyingNFT(fc.trustedSettlementBots[i]) && 
                settlementBots[fc.trustedSettlementBots[i]].monaStaked >= minStakeAmount) {
                anyBotCanSettle = true;
                break;
            }
        }

        if (anyBotCanSettle) revert FGOFuturesErrors.Unauthorized();

        contractSettled[contractId] = true;
        futuresContract.settleFuturesContract(contractId);

        settlements[contractId] = FGOFuturesLibrary.SettlementMetrics({
            settlementTime: block.timestamp,
            delay: timeSinceSettlementDate,
            reward: 0,
            settlementBot: msg.sender
        });

        emit EmergencySettlement(contractId, msg.sender, block.timestamp);
    }

    function getSettlementBot(
        address bot
    ) external view returns (FGOFuturesLibrary.SettlementBot memory) {
        return settlementBots[bot];
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

    function updateSettlementParameters(
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

    function increaseStake(
        uint256 additionalStake
    ) external nonReentrant requiresQualifyingNFT {
        if (settlementBots[msg.sender].botAddress == address(0)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        if (additionalStake == 0) revert FGOFuturesErrors.InvalidAmount();

        address monaToken = accessControl.monaToken();
        IERC20(monaToken).transferFrom(
            msg.sender,
            address(this),
            additionalStake
        );

        settlementBots[msg.sender].monaStaked += additionalStake;

        emit StakeIncreased(settlementBots[msg.sender].monaStaked, msg.sender);
    }

    function _calculateStakeMultiplier(
        address bot
    ) internal view returns (uint256) {
        uint256 botStake = settlementBots[bot].monaStaked;
        if (botStake <= minStakeAmount) {
            return BASIS_POINTS;
        }

        uint256 stakeRatio = (botStake * BASIS_POINTS) / minStakeAmount;
        uint256 multiplier = BASIS_POINTS + ((stakeRatio - BASIS_POINTS) / 2);

        if (multiplier > MAX_STAKE_MULTIPLIER_BPS) {
            return MAX_STAKE_MULTIPLIER_BPS;
        }

        return multiplier;
    }
}
