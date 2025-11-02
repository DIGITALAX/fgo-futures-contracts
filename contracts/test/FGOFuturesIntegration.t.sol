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
            address(lpTreasury),
            MIN_STAKE,
            3600,
            1000
        );

        escrow.setFuturesContract(address(futuresContract));
        escrow.setTradingContract(address(trading));
        futuresContract.setSettlementContract(address(settlement));
        futuresContract.setTradingContract(address(trading));
        trading.setSettlementContract(address(settlement));

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

    function _setupFuturesWithEscrow() internal {
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

        vm.startPrank(trader1);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT);
        trading.buyFromOrder(1, FUTURES_AMOUNT);
        vm.stopPrank();

        fulfillmentContract.setFulfillmentStatus(ORDER_ID, 3, 3);

        vm.warp(fc.futuresSettlementDate + 1);

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
        uint256 totalCostPrimary = FUTURES_AMOUNT * PRICE_PER_UNIT;
        uint256 settlementFeePrimary = (totalCostPrimary * Settlement_REWARD_BPS) / 10000;
        monaToken.approve(address(trading), totalCostPrimary + settlementFeePrimary);
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

        vm.startPrank(trader1);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT);
        trading.buyFromOrder(1, FUTURES_AMOUNT);
        vm.stopPrank();

        fulfillmentContract.setFulfillmentStatus(ORDER_ID, 3, 3);

        vm.warp(fc.futuresSettlementDate + 3601);

        FGOFuturesLibrary.SettlementBot memory settlementBot = settlement
            .getSettlementBot(settlementBot1);

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

    function testSettlementRewardPoolCollection() public {
        _setupFuturesWithEscrow();

        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        vm.startPrank(rightsHolder);
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

        uint256 poolBefore = settlement.getSettlementRewardPool(contractId);
        assertEq(poolBefore, 0, "Pool should start empty");

        vm.startPrank(trader1);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT * 2);
        trading.buyFromOrder(1, FUTURES_AMOUNT);
        vm.stopPrank();

        uint256 expectedFee = (FUTURES_AMOUNT * PRICE_PER_UNIT * Settlement_REWARD_BPS) / 10000;
        uint256 poolAfter = settlement.getSettlementRewardPool(contractId);

        assertEq(poolAfter, expectedFee, "Pool should equal settlement fee collected");
        assertGt(poolAfter, 0, "Pool should be funded");
    }

    function testTokenBalancesChecksDuringBuySell() public {
        _setupFuturesWithEscrow();

        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        vm.startPrank(rightsHolder);
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

        uint256 tokenId = trading.getTotalSupply(1) > 0
            ? uint256(keccak256(abi.encodePacked(address(childContract), CHILD_ID, ORDER_ID, address(marketContract), PRICE_PER_UNIT)))
            : 0;

        uint256 balanceBefore = trading.balanceOf(admin, tokenId);

        vm.startPrank(trader1);
        uint256 trader1BalanceBefore = monaToken.balanceOf(trader1);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT * 2);
        trading.buyFromOrder(1, FUTURES_AMOUNT);
        uint256 trader1BalanceAfter = monaToken.balanceOf(trader1);
        vm.stopPrank();

        uint256 totalCost = FUTURES_AMOUNT * PRICE_PER_UNIT;
        uint256 expectedDeduction = totalCost;

        assertLt(trader1BalanceAfter, trader1BalanceBefore, "Trader balance should decrease");
        assertEq(
            trader1BalanceBefore - trader1BalanceAfter,
            expectedDeduction,
            "Trader should pay total price (settlement fee deducted from it)"
        );
    }

    function testRandomTransferWithSynchronization() public {
        _setupFuturesWithEscrow();

        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        vm.startPrank(rightsHolder);
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

        uint256 tokenId = uint256(keccak256(abi.encodePacked(address(childContract), CHILD_ID, ORDER_ID, address(marketContract), PRICE_PER_UNIT)));

        vm.startPrank(trader1);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT * 2);
        trading.buyFromOrder(1, FUTURES_AMOUNT);

        uint256 trader1Balance = trading.balanceOf(trader1, tokenId);
        assertEq(trader1Balance, FUTURES_AMOUNT, "Trader1 should have bought amount");

        trading.setApprovalForAll(address(trading), true);
        uint256 transferAmount = FUTURES_AMOUNT / 2;
        trading.safeTransferFrom(trader1, trader2, tokenId, transferAmount, "");

        uint256 trader1BalanceAfter = trading.balanceOf(trader1, tokenId);
        uint256 trader2BalanceAfter = trading.balanceOf(trader2, tokenId);

        assertEq(trader1BalanceAfter, FUTURES_AMOUNT - transferAmount, "Trader1 balance should decrease");
        assertEq(trader2BalanceAfter, transferAmount, "Trader2 should receive tokens");
        assertEq(trader1BalanceAfter + trader2BalanceAfter, FUTURES_AMOUNT, "Total tokens should be preserved");

        vm.stopPrank();
    }

    function testTransferBlockedIfReservedTokens() public {
        _setupFuturesWithEscrow();

        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        vm.startPrank(rightsHolder);
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

        uint256 tokenId = uint256(keccak256(abi.encodePacked(address(childContract), CHILD_ID, ORDER_ID, address(marketContract), PRICE_PER_UNIT)));

        vm.startPrank(trader1);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT * 2);
        trading.buyFromOrder(1, FUTURES_AMOUNT);

        trading.setApprovalForAll(address(trading), true);
        trading.createSellOrder(tokenId, FUTURES_AMOUNT, PRICE_PER_UNIT / 2);

        uint256 reserved = trading.getReservedQuantity(trader1, tokenId);
        assertEq(reserved, FUTURES_AMOUNT, "All tokens should be reserved in order");

        vm.expectRevert(FGOFuturesErrors.InsufficientBalance.selector);
        trading.safeTransferFrom(trader1, trader2, tokenId, 1, "");

        vm.stopPrank();
    }

    function testComprehensiveFlowWithFeeTracking() public {
        _setupFuturesWithEscrow();

        address[] memory trustedBots = new address[](3);
        trustedBots[0] = settlementBot1;
        trustedBots[1] = settlementBot2;
        trustedBots[2] = settlementBot3;

        vm.startPrank(rightsHolder);
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

        uint256 tokenId = uint256(keccak256(abi.encodePacked(address(childContract), CHILD_ID, ORDER_ID, address(marketContract), PRICE_PER_UNIT)));

        uint256 protocolFeeBPS = trading.getProtocolFee();
        uint256 lpFeeBPS = trading.getLpFee();

        uint256 primaryBuyAmount1 = 20;
        uint256 primaryBuyAmount2 = 15;
        uint256 primaryBuyAmount3 = 15;

        uint256 protocolTreasuryBefore = monaToken.balanceOf(protocolTreasury);
        uint256 lpTreasuryBefore = monaToken.balanceOf(lpTreasury);
        uint256 settlementPoolBefore = settlement.getSettlementRewardPool(contractId);

        vm.startPrank(trader1);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT * 2);
        trading.buyFromOrder(1, primaryBuyAmount1);
        vm.stopPrank();

        address trader3 = address(0x10);
        address trader4 = address(0x11);
        monaToken.mint(trader3, 1000000 * 10 ** 18);
        monaToken.mint(trader4, 1000000 * 10 ** 18);

        vm.startPrank(trader3);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT * 2);
        trading.buyFromOrder(1, primaryBuyAmount2);
        vm.stopPrank();

        vm.startPrank(trader4);
        monaToken.approve(address(trading), FUTURES_AMOUNT * PRICE_PER_UNIT * 2);
        trading.buyFromOrder(1, primaryBuyAmount3);
        vm.stopPrank();

        uint256 protocolTreasuryAfterPrimary = monaToken.balanceOf(protocolTreasury);
        uint256 lpTreasuryAfterPrimary = monaToken.balanceOf(lpTreasury);
        uint256 settlementPoolAfterPrimary = settlement.getSettlementRewardPool(contractId);

        uint256 totalPrimaryPrice = (primaryBuyAmount1 + primaryBuyAmount2 + primaryBuyAmount3) * PRICE_PER_UNIT;
        uint256 expectedSettlementFeePrimary = (totalPrimaryPrice * Settlement_REWARD_BPS) / 10000;
        uint256 remainingPrimary = totalPrimaryPrice - expectedSettlementFeePrimary;
        uint256 expectedProtocolFeePrimary = (remainingPrimary * protocolFeeBPS) / 10000;
        uint256 expectedLpFeePrimary = (remainingPrimary * lpFeeBPS) / 10000;

        assertEq(
            protocolTreasuryAfterPrimary - protocolTreasuryBefore,
            expectedProtocolFeePrimary,
            "Protocol treasury should receive correct fee after primary"
        );
        assertEq(
            lpTreasuryAfterPrimary - lpTreasuryBefore,
            expectedLpFeePrimary,
            "LP treasury should receive correct fee after primary"
        );
        assertEq(
            settlementPoolAfterPrimary - settlementPoolBefore,
            expectedSettlementFeePrimary,
            "Settlement pool should be funded after primary"
        );

        uint256 trader1TokensAfterPrimary = trading.balanceOf(trader1, tokenId);
        uint256 trader3TokensAfterPrimary = trading.balanceOf(trader3, tokenId);
        uint256 trader4TokensAfterPrimary = trading.balanceOf(trader4, tokenId);

        assertEq(trader1TokensAfterPrimary, primaryBuyAmount1, "Trader1 should have primary amount");
        assertEq(trader3TokensAfterPrimary, primaryBuyAmount2, "Trader3 should have primary amount");
        assertEq(trader4TokensAfterPrimary, primaryBuyAmount3, "Trader4 should have primary amount");

        vm.startPrank(trader1);
        trading.setApprovalForAll(address(trading), true);
        uint256 secondaryPrice1 = (PRICE_PER_UNIT * 120) / 100;
        uint256 sellOrderId1 = trading.createSellOrder(tokenId, 10, secondaryPrice1);
        vm.stopPrank();

        vm.startPrank(trader3);
        monaToken.approve(address(trading), 10 * secondaryPrice1 * 2);
        trading.buyFromOrder(sellOrderId1, 10);
        vm.stopPrank();

        uint256 protocolTreasuryAfterSecondary = monaToken.balanceOf(protocolTreasury);
        uint256 lpTreasuryAfterSecondary = monaToken.balanceOf(lpTreasury);

        uint256 secondaryPrice = 10 * secondaryPrice1;
        uint256 expectedProtocolFeeSecondary = (secondaryPrice * protocolFeeBPS) / 10000;
        uint256 expectedLpFeeSecondary = (secondaryPrice * lpFeeBPS) / 10000;

        assertEq(
            protocolTreasuryAfterSecondary - protocolTreasuryAfterPrimary,
            expectedProtocolFeeSecondary,
            "Protocol should receive fee on secondary sale"
        );
        assertEq(
            lpTreasuryAfterSecondary - lpTreasuryAfterPrimary,
            expectedLpFeeSecondary,
            "LP should receive fee on secondary sale"
        );

        uint256 trader1TokensAfterSecondary = trading.balanceOf(trader1, tokenId);
        uint256 trader3TokensAfterSecondary = trading.balanceOf(trader3, tokenId);

        assertEq(trader1TokensAfterSecondary, 10, "Trader1 should have 10 left after selling 10");
        assertEq(trader3TokensAfterSecondary, primaryBuyAmount2 + 10, "Trader3 should have primary + secondary");

        vm.startPrank(trader3);
        trading.setApprovalForAll(address(trading), true);
        uint256 secondaryPrice2 = (PRICE_PER_UNIT * 130) / 100;
        uint256 sellOrderId2 = trading.createSellOrder(tokenId, 5, secondaryPrice2);
        vm.stopPrank();

        vm.startPrank(trader4);
        monaToken.approve(address(trading), 5 * secondaryPrice2 * 2);
        trading.buyFromOrder(sellOrderId2, 5);
        vm.stopPrank();

        uint256 trader3TokensAfterSecondary2 = trading.balanceOf(trader3, tokenId);
        uint256 trader4TokensAfterSecondary2 = trading.balanceOf(trader4, tokenId);

        assertEq(trader3TokensAfterSecondary2, 20, "Trader3 should have 20 left after selling 5");
        assertEq(trader4TokensAfterSecondary2, primaryBuyAmount3 + 5, "Trader4 should have primary + secondary");

        FGOFuturesLibrary.FuturesContract memory fc = futuresContract.getFuturesContract(contractId);
        fulfillmentContract.setFulfillmentStatus(ORDER_ID, 3, 3);
        vm.warp(fc.futuresSettlementDate + 1);

        uint256 botBalanceBefore = monaToken.balanceOf(settlementBot1);
        uint256 settlementPoolBeforeSettle = settlement.getSettlementRewardPool(contractId);

        vm.startPrank(settlementBot1);
        settlement.settleFuturesContract(contractId);
        vm.stopPrank();

        uint256 botBalanceAfter = monaToken.balanceOf(settlementBot1);
        uint256 settlementPoolAfterSettle = settlement.getSettlementRewardPool(contractId);

        assertGt(botBalanceAfter, botBalanceBefore, "Bot should receive reward");
        assertLt(settlementPoolAfterSettle, settlementPoolBeforeSettle, "Settlement pool should be depleted by bot reward");

        uint256 trader1FinalTokens = trading.balanceOf(trader1, tokenId);
        uint256 trader3FinalTokens = trading.balanceOf(trader3, tokenId);
        uint256 trader4FinalTokens = trading.balanceOf(trader4, tokenId);

        assertEq(trader1FinalTokens, 10, "Trader1 should still have 10 futures tokens before claim");
        assertEq(trader3FinalTokens, 20, "Trader3 should have 20 futures tokens before claim");
        assertEq(trader4FinalTokens, 20, "Trader4 should have 20 futures tokens before claim");

        vm.startPrank(trader1);
        escrow.claimChildAfterSettlement(contractId);
        vm.stopPrank();

        vm.startPrank(trader3);
        escrow.claimChildAfterSettlement(contractId);
        vm.stopPrank();

        vm.startPrank(trader4);
        escrow.claimChildAfterSettlement(contractId);
        vm.stopPrank();

        uint256 trader1ChildBalance = childContract.balanceOf(trader1, CHILD_ID);
        uint256 trader3ChildBalance = childContract.balanceOf(trader3, CHILD_ID);
        uint256 trader4ChildBalance = childContract.balanceOf(trader4, CHILD_ID);

        assertEq(trader1ChildBalance, trader1FinalTokens, "Trader1 should receive child equal to final tokens");
        assertEq(trader3ChildBalance, trader3FinalTokens, "Trader3 should receive child equal to final tokens");
        assertEq(trader4ChildBalance, trader4FinalTokens, "Trader4 should receive child equal to final tokens");

        assertEq(trading.balanceOf(trader1, tokenId), 0, "Trader1 should burn all futures tokens");
        assertEq(trading.balanceOf(trader3, tokenId), 0, "Trader3 should burn all futures tokens");
        assertEq(trading.balanceOf(trader4, tokenId), 0, "Trader4 should burn all futures tokens");

        assertTrue(settlement.isContractSettled(contractId), "Contract should be settled");
        assertTrue(futuresContract.getFuturesContract(contractId).isSettled, "Contract should be marked settled");
    }
}
