// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/FGOFuturesAccessControl.sol";
import "../src/FGOFuturesContract.sol";
import "../src/FGOFuturesEscrow.sol";
import "../src/FGOFuturesTrading.sol";
import "../src/FGOFuturesSettlement.sol";
import "../src/interfaces/IFGOPhysicalRights.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MONA", "MONA") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockERC721 is ERC721 {
    constructor() ERC721("QualifyingNFT", "QUAL") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }
}

contract MockFGOChild is MockERC1155 {
    mapping(uint256 => mapping(uint256 => mapping(address => mapping(address => bool))))
        private physicalRightsHolders;

    function transferPhysicalRights(
        uint256 childId,
        uint256 orderId,
        uint256 amount,
        address to,
        address marketContract
    ) external {
        physicalRightsHolders[childId][orderId][to][marketContract] = true;
    }

    function getIsPhysicalRightsHolder(
        uint256 childId,
        uint256 orderId,
        address to,
        address marketContract
    ) external view returns (bool) {
        return physicalRightsHolders[childId][orderId][to][marketContract];
    }

    function getPhysicalRights(
        uint256 childId,
        uint256 orderId,
        address buyer,
        address marketContract
    ) external view returns (FGOLibrary.PhysicalRights memory) {
        return
            FGOLibrary.PhysicalRights({
                guaranteedAmount: 100,
                estimatedDeliveryDuration: 7 days,
                purchaseMarket: marketContract
            });
    }
}

contract MockFGOMarket {
    address public fulfillment;
    mapping(uint256 => FGOMarketLibrary.OrderReceipt) private orders;

    constructor(address _fulfillment) {
        fulfillment = _fulfillment;
    }

    function setOrderReceipt(uint256 orderId, address buyer) external {
        orders[orderId].timestamp = block.timestamp;
        orders[orderId].orderId = orderId;
        orders[orderId].buyer = buyer;
        orders[orderId].params.parentId = 0;
        orders[orderId].params.parentAmount = 0;
        orders[orderId].params.childId = 1;
        orders[orderId].params.childAmount = 100;
        orders[orderId].params.templateId = 0;
        orders[orderId].params.templateAmount = 0;
        orders[orderId].params.parentContract = address(0);
        orders[orderId].params.childContract = address(0);
        orders[orderId].params.templateContract = address(0);
        orders[orderId].params.isPhysical = true;
        orders[orderId].params.fulfillmentData = "";
        orders[orderId].breakdown.totalPayments = 1;
        orders[orderId].status = FGOMarketLibrary.OrderStatus.PAID;
    }

    function getOrderReceipt(
        uint256 orderId
    ) external view returns (FGOMarketLibrary.OrderReceipt memory) {
        return orders[orderId];
    }
}

contract MockFGOFulfillment {
    function getFulfillmentStatus(
        uint256 orderId
    ) external view returns (FGOMarketLibrary.FulfillmentStatus memory status) {
        FGOMarketLibrary.StepCompletion[]
            memory steps = new FGOMarketLibrary.StepCompletion[](3);

        steps[0] = FGOMarketLibrary.StepCompletion({
            completedAt: 1000,
            fulfiller: address(this),
            isCompleted: true,
            notes: ""
        });

        steps[1] = FGOMarketLibrary.StepCompletion({
            completedAt: 1000,
            fulfiller: address(this),
            isCompleted: true,
            notes: ""
        });

        steps[2] = FGOMarketLibrary.StepCompletion({
            completedAt: 1000,
            fulfiller: address(this),
            isCompleted: true,
            notes: ""
        });

        status = FGOMarketLibrary.FulfillmentStatus({
            orderId: orderId,
            parentId: 1,
            currentStep: 3,
            createdAt: 500,
            lastUpdated: 1000,
            parentContract: address(0),
            steps: steps
        });
    }

    function setFulfillmentStatus(uint256, uint256, uint256) external {
        // No-op for compatibility
    }
}

contract FGOFuturesIntegrationTest is Test {
    FGOFuturesAccessControl accessControl;
    FGOFuturesContract futuresContract;
    FGOFuturesEscrow escrow;
    FGOFuturesTrading trading;
    FGOFuturesSettlement settlement;

    MockERC20 monaToken;
    MockERC721 qualifyingNFT;
    MockFGOChild childContract;
    MockFGOMarket marketContract;
    MockFGOFulfillment fulfillmentContract;

    address admin = address(0x1);
    address rightsHolder = address(0x2);
    address settlementBot1 = address(0x3);
    address settlementBot2 = address(0x4);
    address settlementBot3 = address(0x5);
    address trader1 = address(0x6);
    address trader2 = address(0x7);
    address lpTreasury = address(0x8);
    address protocolTreasury = address(0x9);

    uint256 constant CHILD_ID = 1;
    uint256 constant ORDER_ID = 1;
    uint256 constant ESCROW_AMOUNT = 100;
    uint256 constant FUTURES_AMOUNT = 50;
    uint256 constant PRICE_PER_UNIT = 1000 * 10 ** 18;
    uint256 constant Settlement_REWARD_BPS = 200;
    uint256 constant MIN_STAKE = 10000 * 10 ** 18;

    function setUp() public {
        vm.startPrank(admin);

        monaToken = new MockERC20();
        qualifyingNFT = new MockERC721();
        childContract = new MockFGOChild();
        fulfillmentContract = new MockFGOFulfillment();
        marketContract = new MockFGOMarket(address(fulfillmentContract));

        address[] memory validTokens = new address[](1);
        validTokens[0] = address(qualifyingNFT);

        accessControl = new FGOFuturesAccessControl(address(monaToken));
        escrow = new FGOFuturesEscrow(address(accessControl));
        futuresContract = new FGOFuturesContract(
            address(accessControl),
            address(escrow),
            validTokens
        );

        trading = new FGOFuturesTrading(
            address(accessControl),
            address(futuresContract),
            address(escrow),
            lpTreasury,
            protocolTreasury,
            100,
            50
        );
        settlement = new FGOFuturesSettlement(
            address(accessControl),
            address(futuresContract),
            address(escrow),
            address(trading),
            MIN_STAKE,
            3600,
            1000
        );

        escrow.setFuturesContract(address(futuresContract));
        escrow.setTradingContract(address(trading));
        futuresContract.setSettlementContract(address(settlement));
        futuresContract.setTradingContract(address(trading));

        monaToken.mint(rightsHolder, 1000000 * 10 ** 18);
        monaToken.mint(settlementBot1, 1000000 * 10 ** 18);
        monaToken.mint(settlementBot2, 1000000 * 10 ** 18);
        monaToken.mint(settlementBot3, 1000000 * 10 ** 18);
        monaToken.mint(trader1, 1000000 * 10 ** 18);
        monaToken.mint(trader2, 1000000 * 10 ** 18);

        qualifyingNFT.mint(settlementBot1, 1);
        qualifyingNFT.mint(settlementBot2, 2);
        qualifyingNFT.mint(settlementBot3, 3);

        marketContract.setOrderReceipt(ORDER_ID, rightsHolder);

        childContract.mint(address(escrow), CHILD_ID, 1000);

        vm.stopPrank();
    }

    function test_DepositRights() public {
        vm.startPrank(rightsHolder);
        childContract.transferPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(escrow),
            address(marketContract)
        );

        escrow.depositPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(marketContract),
            address(childContract)
        );
        vm.stopPrank();
    }

    function test_SettlementBotRegistration() public {
        vm.startPrank(settlementBot1);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        FGOFuturesLibrary.SettlementBot memory bot = settlement
            .getSettlementBot(settlementBot1);
        assertEq(bot.botAddress, settlementBot1);
        assertEq(bot.monaStaked, MIN_STAKE);
    }

    function test_SettlementWorkflow() public {
        vm.startPrank(rightsHolder);
        childContract.transferPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(escrow),
            address(marketContract)
        );

        escrow.depositPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(marketContract),
            address(childContract)
        );
        vm.stopPrank();

        vm.startPrank(settlementBot1);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(rightsHolder);
        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        uint256 contractId = futuresContract.openFuturesContract(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            PRICE_PER_UNIT,
            Settlement_REWARD_BPS,
            address(childContract),
            address(marketContract),
            trustedBots,
            ""
        );

        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);
        uint256 tokenId = fc.tokenId;
        vm.stopPrank();

        fulfillmentContract.setFulfillmentStatus(ORDER_ID, 3, 3);

        vm.warp(fc.futuresSettlementDate + 1);

        uint256 totalReward = (FUTURES_AMOUNT *
            PRICE_PER_UNIT *
            Settlement_REWARD_BPS) / 10000;

        vm.startPrank(rightsHolder);
        monaToken.approve(address(settlement), totalReward);
        vm.stopPrank();

        vm.startPrank(settlementBot1);
        settlement.settleFuturesContract(contractId);
        vm.stopPrank();

        assertTrue(settlement.isContractSettled(contractId));
    }

    function test_CreateFuturesContract() public {
        vm.startPrank(rightsHolder);
        childContract.transferPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(escrow),
            address(marketContract)
        );

        escrow.depositPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(marketContract),
            address(childContract)
        );
        vm.stopPrank();

        vm.startPrank(settlementBot1);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(rightsHolder);
        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        uint256 contractId = futuresContract.openFuturesContract(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            PRICE_PER_UNIT,
            Settlement_REWARD_BPS,
            address(childContract),
            address(marketContract),
            trustedBots,
            ""
        );
        vm.stopPrank();

        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);
        assertEq(fc.quantity, FUTURES_AMOUNT);
        assertEq(fc.pricePerUnit, PRICE_PER_UNIT);
        assertTrue(fc.isActive);
        assertFalse(fc.isSettled);
    }

    function test_FullWorkflow() public {
        vm.startPrank(rightsHolder);
        childContract.transferPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(escrow),
            address(marketContract)
        );

        escrow.depositPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(marketContract),
            address(childContract)
        );

        vm.stopPrank();

        vm.startPrank(settlementBot1);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(rightsHolder);
        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        uint256 contractId = futuresContract.openFuturesContract(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            PRICE_PER_UNIT,
            Settlement_REWARD_BPS,
            address(childContract),
            address(marketContract),
            trustedBots,
            ""
        );
        vm.stopPrank();

        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);

        vm.startPrank(trader1);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT);
        trading.buyFromOrder(1, FUTURES_AMOUNT);
        vm.stopPrank();

        uint256 tokenId = fc.tokenId;

        vm.startPrank(trader1);
        uint256 sellOrderId = trading.createSellOrder(
            tokenId,
            20,
            (PRICE_PER_UNIT * 110) / 100
        );
        vm.stopPrank();

        vm.startPrank(trader2);
        monaToken.approve(
            address(trading),
            (20 * PRICE_PER_UNIT * 110) / 100 + 1000
        );
        trading.buyFromOrder(sellOrderId, 20);
        vm.stopPrank();

        fulfillmentContract.setFulfillmentStatus(ORDER_ID, 3, 3);

        vm.warp(fc.futuresSettlementDate - 1);

        vm.startPrank(settlementBot1);
        vm.expectRevert();
        settlement.settleFuturesContract(contractId);
        vm.stopPrank();

        vm.warp(fc.futuresSettlementDate + 1);

        vm.startPrank(rightsHolder);
        monaToken.approve(
            address(settlement),
            (FUTURES_AMOUNT * PRICE_PER_UNIT * Settlement_REWARD_BPS) / 10000
        );
        vm.stopPrank();

        vm.startPrank(settlementBot1);
        settlement.settleFuturesContract(contractId);
        vm.stopPrank();

        uint256 trader1Balance = trading.balanceOf(trader1, tokenId);
        uint256 trader2Balance = trading.balanceOf(trader2, tokenId);

        vm.startPrank(trader1);
        escrow.claimChildAfterSettlement(contractId);
        vm.stopPrank();

        vm.startPrank(trader2);
        escrow.claimChildAfterSettlement(contractId);
        vm.stopPrank();

        assertEq(childContract.balanceOf(trader1, CHILD_ID), trader1Balance);
        assertEq(childContract.balanceOf(trader2, CHILD_ID), trader2Balance);
        assertEq(trading.balanceOf(trader1, tokenId), 0);
        assertEq(trading.balanceOf(trader2, tokenId), 0);

        assertTrue(futuresContract.getFuturesContract(contractId).isSettled);
        assertTrue(settlement.isContractSettled(contractId));
    }

    function test_SettlementBotSlashing() public {
        vm.startPrank(rightsHolder);
        childContract.transferPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(escrow),
            address(marketContract)
        );

        escrow.depositPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(marketContract),
            address(childContract)
        );
        vm.stopPrank();

        vm.startPrank(settlementBot1);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(rightsHolder);
        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        uint256 contractId = futuresContract.openFuturesContract(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            PRICE_PER_UNIT,
            Settlement_REWARD_BPS,
            address(childContract),
            address(marketContract),
            trustedBots,
            ""
        );

        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);
        vm.stopPrank();

        fulfillmentContract.setFulfillmentStatus(ORDER_ID, 3, 3);

        vm.warp(fc.futuresSettlementDate + 3601);

        FGOFuturesLibrary.SettlementBot memory settlementBot = settlement
            .getSettlementBot(settlementBot1);

        vm.startPrank(rightsHolder);
        monaToken.approve(
            address(settlement),
            (FUTURES_AMOUNT * PRICE_PER_UNIT * Settlement_REWARD_BPS) / 10000
        );
        vm.stopPrank();

        vm.startPrank(settlementBot1);
        settlement.settleFuturesContract(contractId);
        vm.stopPrank();

        uint256 finalStake = settlement
            .getSettlementBot(settlementBot1)
            .monaStaked;
        assertTrue(finalStake < settlementBot.monaStaked);

        FGOFuturesLibrary.SettlementBot memory bot = settlement
            .getSettlementBot(settlementBot1);
        assertEq(bot.slashEvents, 1);
    }

    function testCancelFuturesContractSuccess() public {
        vm.startPrank(settlementBot1);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(rightsHolder);
        childContract.transferPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            address(escrow),
            address(marketContract)
        );

        escrow.depositPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            address(marketContract),
            address(childContract)
        );

        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        uint256 contractId = futuresContract.openFuturesContract(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            PRICE_PER_UNIT,
            Settlement_REWARD_BPS,
            address(childContract),
            address(marketContract),
            trustedBots,
            ""
        );

        FGOFuturesLibrary.EscrowedRights memory rightsBefore = escrow
            .getEscrowedRights(
                CHILD_ID,
                ORDER_ID,
                address(childContract),
                address(marketContract),
                rightsHolder
            );

        assertEq(rightsBefore.amountUsedForFutures, FUTURES_AMOUNT);

        futuresContract.cancelFuturesContract(contractId);

        FGOFuturesLibrary.EscrowedRights memory rightsAfter = escrow
            .getEscrowedRights(
                CHILD_ID,
                ORDER_ID,
                address(childContract),
                address(marketContract),
                rightsHolder
            );

        assertEq(rightsAfter.amountUsedForFutures, 0);

        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);
        assertFalse(fc.isActive);
        vm.stopPrank();
    }

    function testCancelFuturesContractFailsAfterPurchase() public {
        vm.startPrank(settlementBot1);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(rightsHolder);
        childContract.transferPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            address(escrow),
            address(marketContract)
        );

        escrow.depositPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            address(marketContract),
            address(childContract)
        );

        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        uint256 contractId = futuresContract.openFuturesContract(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            PRICE_PER_UNIT,
            Settlement_REWARD_BPS,
            address(childContract),
            address(marketContract),
            trustedBots,
            ""
        );
        vm.stopPrank();

        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);
        uint256 tokenId = fc.tokenId;

        // Primera orden creada automáticamente al abrir el contrato
        vm.startPrank(trader1);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT);
        trading.buyFromOrder(1, FUTURES_AMOUNT);
        vm.stopPrank();

        vm.startPrank(rightsHolder);
        vm.expectRevert(FGOFuturesErrors.TokensAlreadyTraded.selector);
        futuresContract.cancelFuturesContract(contractId);
        vm.stopPrank();
    }

    function testCancelFuturesContractUnauthorized() public {
        vm.startPrank(settlementBot1);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(rightsHolder);
        childContract.transferPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            address(escrow),
            address(marketContract)
        );

        escrow.depositPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            address(marketContract),
            address(childContract)
        );

        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        uint256 contractId = futuresContract.openFuturesContract(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            PRICE_PER_UNIT,
            Settlement_REWARD_BPS,
            address(childContract),
            address(marketContract),
            trustedBots,
            ""
        );
        vm.stopPrank();

        vm.startPrank(trader1);
        vm.expectRevert(FGOFuturesErrors.Unauthorized.selector);
        futuresContract.cancelFuturesContract(contractId);
        vm.stopPrank();
    }

    function testEmergencySettlement() public {
        vm.startPrank(settlementBot1);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(rightsHolder);
        childContract.transferPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(escrow),
            address(marketContract)
        );

        escrow.depositPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(marketContract),
            address(childContract)
        );

        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        uint256 contractId = futuresContract.openFuturesContract(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            PRICE_PER_UNIT,
            Settlement_REWARD_BPS,
            address(childContract),
            address(marketContract),
            trustedBots,
            ""
        );

        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);
        vm.stopPrank();

        fulfillmentContract.setFulfillmentStatus(ORDER_ID, 3, 3);

        vm.startPrank(settlementBot1);
        qualifyingNFT.transferFrom(settlementBot1, address(0xdead), 1);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        qualifyingNFT.transferFrom(settlementBot2, address(0xdead), 2);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        qualifyingNFT.transferFrom(settlementBot3, address(0xdead), 3);
        vm.stopPrank();

        vm.warp(fc.futuresSettlementDate + 3601);

        vm.startPrank(rightsHolder);
        settlement.emergencySettleFuturesContract(contractId);
        vm.stopPrank();

        assertTrue(settlement.isContractSettled(contractId));
        assertTrue(futuresContract.getFuturesContract(contractId).isSettled);
    }

    function testEmergencySettlementFailsWhenSettlementBotsCanStillSettle()
        public
    {
        vm.startPrank(settlementBot1);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(rightsHolder);
        childContract.transferPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(escrow),
            address(marketContract)
        );

        escrow.depositPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(marketContract),
            address(childContract)
        );

        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        uint256 contractId = futuresContract.openFuturesContract(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            PRICE_PER_UNIT,
            Settlement_REWARD_BPS,
            address(childContract),
            address(marketContract),
            trustedBots,
            ""
        );

        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);
        vm.stopPrank();

        fulfillmentContract.setFulfillmentStatus(ORDER_ID, 3, 3);

        vm.warp(fc.futuresSettlementDate + 2000);

        vm.startPrank(rightsHolder);
        vm.expectRevert(FGOFuturesErrors.SettlementNotReady.selector);
        settlement.emergencySettleFuturesContract(contractId);
        vm.stopPrank();
    }

    function testEmergencySettlementByFuturesHolder() public {
        vm.startPrank(settlementBot1);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        monaToken.approve(address(settlement), MIN_STAKE);
        settlement.registerSettlementBot(MIN_STAKE);
        vm.stopPrank();

        vm.startPrank(rightsHolder);
        childContract.transferPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(escrow),
            address(marketContract)
        );

        escrow.depositPhysicalRights(
            CHILD_ID,
            ORDER_ID,
            ESCROW_AMOUNT,
            address(marketContract),
            address(childContract)
        );

        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        uint256 contractId = futuresContract.openFuturesContract(
            CHILD_ID,
            ORDER_ID,
            FUTURES_AMOUNT,
            PRICE_PER_UNIT,
            Settlement_REWARD_BPS,
            address(childContract),
            address(marketContract),
            trustedBots,
            ""
        );
        vm.stopPrank();

        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);

        vm.startPrank(trader1);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT);
        trading.buyFromOrder(1, FUTURES_AMOUNT);
        vm.stopPrank();

        fulfillmentContract.setFulfillmentStatus(ORDER_ID, 3, 3);

        vm.startPrank(settlementBot1);
        qualifyingNFT.transferFrom(settlementBot1, address(0xdead), 1);
        vm.stopPrank();

        vm.startPrank(settlementBot2);
        qualifyingNFT.transferFrom(settlementBot2, address(0xdead), 2);
        vm.stopPrank();

        vm.startPrank(settlementBot3);
        qualifyingNFT.transferFrom(settlementBot3, address(0xdead), 3);
        vm.stopPrank();

        vm.warp(fc.futuresSettlementDate + 3601);

        vm.startPrank(trader1);
        settlement.emergencySettleFuturesContract(contractId);
        vm.stopPrank();

        assertTrue(settlement.isContractSettled(contractId));
        assertTrue(futuresContract.getFuturesContract(contractId).isSettled);
    }
}
