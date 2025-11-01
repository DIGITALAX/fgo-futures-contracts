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
    uint256 private _minStakeAmount;
    uint256 private _maxSettlementDelay;
    uint256 private _slashPercentageBPS;

    mapping(address => FGOFuturesLibrary.SettlementBot) private _settlementBots;
    mapping(uint256 => FGOFuturesLibrary.SettlementMetrics) private _settlements;
    mapping(uint256 => bool) private _contractSettled;
    mapping(uint256 => uint256) private _settlementRewardPool;

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

    modifier requiresQualifyingNFT() {
        if (!hasQualifyingNFT(msg.sender)) {
            revert FGOFuturesErrors.SettlementBotLacksQualifyingNFT();
        }
        _;
    }

    modifier onlyTradingContract() {
        if (msg.sender != address(trading)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _;
    }

    constructor(
        address _accessControl,
        address _futuresContract,
        address _escrow,
        address _trading,
        uint256 minStakeAmount,
        uint256 maxSettlementDelay,
        uint256 slashPercentageBPS
    ) {
        accessControl = FGOFuturesAccessControl(_accessControl);
        futuresContract = FGOFuturesContract(_futuresContract);
        escrow = FGOFuturesEscrow(_escrow);
        trading = FGOFuturesTrading(_trading);
        _minStakeAmount = minStakeAmount;
        _maxSettlementDelay = maxSettlementDelay;
        _slashPercentageBPS = slashPercentageBPS;
        symbol = "FGOSET";
        name = "FGOFuturesSettlement";
    }

    function registerSettlementBot(
        uint256 stakeAmount
    ) external nonReentrant requiresQualifyingNFT {
        if (stakeAmount < _minStakeAmount)
            revert FGOFuturesErrors.InvalidAmount();

        uint256 currentStake = _settlementBots[msg.sender].monaStaked;
        if (currentStake > 0) revert FGOFuturesErrors.AlreadyRegistered();

        address monaToken = accessControl.monaToken();
        IERC20(monaToken).transferFrom(msg.sender, address(this), stakeAmount);

        _settlementBots[msg.sender] = FGOFuturesLibrary.SettlementBot({
            totalSettlements: 0,
            averageDelaySeconds: 0,
            monaStaked: stakeAmount,
            slashEvents: 0,
            botAddress: msg.sender
        });

        emit SettlementBotRegistered(stakeAmount, msg.sender);
    }

    function addToRewardPool(
        uint256 contractId,
        uint256 amount
    ) external onlyTradingContract {
        if (amount == 0) revert FGOFuturesErrors.InvalidAmount();
        _settlementRewardPool[contractId] += amount;
    }

    function settleFuturesContract(
        uint256 contractId
    ) external nonReentrant {
        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);

        if (fc.isSettled) revert FGOFuturesErrors.AlreadySettled();
        if (!fc.isActive) revert FGOFuturesErrors.ContractNotActive();
        if (_contractSettled[contractId])
            revert FGOFuturesErrors.AlreadySettled();

        if (block.timestamp < fc.futuresSettlementDate)
            revert FGOFuturesErrors.SettlementNotReady();

        uint256 availableReward = _settlementRewardPool[contractId];
        uint256 settlementDelay = block.timestamp - fc.futuresSettlementDate;
        address monaToken = accessControl.monaToken();

        if (availableReward == 0) {
            _contractSettled[contractId] = true;
            futuresContract.settleFuturesContract(contractId);

            _settlements[contractId] = FGOFuturesLibrary.SettlementMetrics({
                settlementTime: block.timestamp,
                delay: settlementDelay,
                reward: 0,
                settlementBot: msg.sender
            });

            emit ContractSettled(contractId, 0, fc.futuresSettlementDate, msg.sender);
            return;
        }

        _requireTrustedSettlementBot(contractId);

        if (settlementDelay > _maxSettlementDelay) {
            uint256 slashAmount = (_settlementBots[msg.sender].monaStaked *
                _slashPercentageBPS) / BASIS_POINTS;
            _settlementBots[msg.sender].monaStaked -= slashAmount;
            _settlementBots[msg.sender].slashEvents++;

            IERC20(monaToken).transfer(fc.originalHolder, slashAmount);

            emit SettlementBotSlashed(slashAmount, msg.sender);
        }

        uint256 settlerStake = _settlementBots[msg.sender].monaStaked;
        uint256 maxOtherStake = 0;

        for (uint256 i = 0; i < fc.trustedSettlementBots.length; i++) {
            address otherBot = fc.trustedSettlementBots[i];
            if (otherBot != msg.sender) {
                uint256 otherStake = _settlementBots[otherBot].monaStaked;
                if (otherStake > maxOtherStake) {
                    maxOtherStake = otherStake;
                }
            }
        }

        if (settlerStake < maxOtherStake) {
            uint256 stakeDifference = maxOtherStake - settlerStake;
            uint256 stakeBasedSlash = (stakeDifference * _slashPercentageBPS) /
                BASIS_POINTS;

            uint256 maxSlash = (settlerStake * 5000) / BASIS_POINTS;
            uint256 actualSlash = stakeBasedSlash > maxSlash ? maxSlash : stakeBasedSlash;

            _settlementBots[msg.sender].monaStaked -= actualSlash;
            IERC20(monaToken).transfer(fc.originalHolder, actualSlash);

            emit SettlementBotSlashed(actualSlash, msg.sender);
        }

        _settlementRewardPool[contractId] = 0;
        IERC20(monaToken).transfer(msg.sender, availableReward);

        _contractSettled[contractId] = true;

        futuresContract.settleFuturesContract(contractId);

        _settlements[contractId] = FGOFuturesLibrary.SettlementMetrics({
            settlementTime: block.timestamp,
            delay: settlementDelay,
            reward: availableReward,
            settlementBot: msg.sender
        });

        _settlementBots[msg.sender].totalSettlements++;
        uint256 oldAverage = _settlementBots[msg.sender].averageDelaySeconds;
        uint256 newAverage = (oldAverage *
            (_settlementBots[msg.sender].totalSettlements - 1) +
            settlementDelay) / _settlementBots[msg.sender].totalSettlements;
        _settlementBots[msg.sender].averageDelaySeconds = newAverage;

        emit ContractSettled(
            contractId,
            availableReward,
            fc.futuresSettlementDate,
            msg.sender
        );
    }

    function withdrawStake() external nonReentrant {
        uint256 amount = _settlementBots[msg.sender].monaStaked;
        if (amount == 0) revert FGOFuturesErrors.NoStakeToWithdraw();

        _settlementBots[msg.sender].monaStaked = 0;

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
        if (_contractSettled[contractId])
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

        if (timeSinceSettlementDate <= _maxSettlementDelay)
            revert FGOFuturesErrors.SettlementNotReady();

        bool anyBotCanSettle = false;
        for (uint256 i = 0; i < fc.trustedSettlementBots.length; i++) {
            if (hasQualifyingNFT(fc.trustedSettlementBots[i]) && 
                _settlementBots[fc.trustedSettlementBots[i]].monaStaked >= _minStakeAmount) {
                anyBotCanSettle = true;
                break;
            }
        }

        if (anyBotCanSettle) revert FGOFuturesErrors.Unauthorized();

        _contractSettled[contractId] = true;
        futuresContract.settleFuturesContract(contractId);

        _settlements[contractId] = FGOFuturesLibrary.SettlementMetrics({
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
        return _settlementBots[bot];
    }

    function getSettlementMetrics(
        uint256 contractId
    ) external view returns (FGOFuturesLibrary.SettlementMetrics memory) {
        return _settlements[contractId];
    }

    function isContractSettled(
        uint256 contractId
    ) external view returns (bool) {
        return _contractSettled[contractId];
    }

    function getSettlementRewardPool(
        uint256 contractId
    ) external view returns (uint256) {
        return _settlementRewardPool[contractId];
    }

    function updateSettlementParameters(
        uint256 minStakeAmount,
        uint256 maxSettlementDelay,
        uint256 slashPercentageBPS
    ) external onlyAdmin {
        _minStakeAmount = minStakeAmount;
        _maxSettlementDelay = maxSettlementDelay;
        _slashPercentageBPS = slashPercentageBPS;
    }

    function getMinStakeAmount() external view returns (uint256) {
        return _minStakeAmount;
    }

    function getMaxSettlementDelay() external view returns (uint256) {
        return _maxSettlementDelay;
    }

    function getSlashPercentageBPS() external view returns (uint256) {
        return _slashPercentageBPS;
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
        if (_settlementBots[msg.sender].botAddress == address(0)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        if (additionalStake == 0) revert FGOFuturesErrors.InvalidAmount();

        address monaToken = accessControl.monaToken();
        IERC20(monaToken).transferFrom(
            msg.sender,
            address(this),
            additionalStake
        );

        _settlementBots[msg.sender].monaStaked += additionalStake;

        emit StakeIncreased(_settlementBots[msg.sender].monaStaked, msg.sender);
    }

    function _requireTrustedSettlementBot(uint256 contractId) internal view {
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
        if (_settlementBots[msg.sender].monaStaked < _minStakeAmount) {
            revert FGOFuturesErrors.InsufficientStake();
        }
    }
}
