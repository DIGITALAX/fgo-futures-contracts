import { BigInt, Bytes, ByteArray, Address } from "@graphprotocol/graph-ts";
import {
  Fulfillment,
  FulfillmentOrderStep,
  ChildOrder,
  FuturesContract,
  OrderToContract,
} from "../generated/schema";
import {
  StepCompleted as StepCompletedEvent,
  FulfillmentCompleted as FulfillmentCompletedEvent,
  FulfillmentStarted as FulfillmentStartedEvent,
  FGOFulfillment,
} from "../generated/templates/FGOFulfillment/FGOFulfillment";
import { FGOMarket } from "../generated/templates/FGOMarket/FGOMarket";
import { FGOFuturesSettlement } from "../generated/FGOFuturesSettlement/FGOFuturesSettlement";
import { FGOFuturesContract } from "../generated/FGOFuturesContract/FGOFuturesContract";

export function handleStepCompleted(event: StepCompletedEvent): void {
  let fulfillment = FGOFulfillment.bind(event.address);
  let data = fulfillment.getFulfillmentStatus(event.params.orderId);
  let entity = Fulfillment.load(
    Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.orderId.toString() +
        data.parentContract.toHexString() +
        data.parentId.toHexString()
    )
  );

  if (entity) {
    entity.currentStep = data.currentStep;
    entity.lastUpdated = data.lastUpdated;
    entity.save();
  }

  let marketAddress = fulfillment.market();
  let market = FGOMarket.bind(marketAddress);
  let orderData = market.getOrderReceipt(event.params.orderId);

  let orderLookupId = Bytes.fromUTF8(
    orderData.params.childContract.toHexString() +
      "-" +
      orderData.params.childId.toString() +
      "-" +
      event.params.orderId.toString() +
      "-" +
      marketAddress.toHexString()
  );

  let orderLookup = OrderToContract.load(orderLookupId);
  if (orderLookup) {
    let contract = FuturesContract.load(
      Bytes.fromByteArray(ByteArray.fromBigInt(orderLookup.contractId))
    );

    if (contract) {
      let futuresContract = FGOFuturesContract.bind(
        orderLookup.futuresContract as Address
      );
      let settlement = FGOFuturesSettlement.bind(
        futuresContract.settlementContract()
      );
      contract.timeSinceCompletion = settlement.getMaxSettlementDelay();
      contract.maxSettlementDelay = data.lastUpdated;
      contract.save();
    }
  }

  let step = data.steps[event.params.stepIndex.toI32()];
  let isPhysical = orderData.params.isPhysical;

  let stepId =
    data.parentContract.toHexString() +
    "-" +
    data.parentId.toHexString() +
    "-" +
    event.params.stepIndex.toString();

  if (isPhysical) {
    stepId = stepId + "-physical";
  }

  let entitySteps = FulfillmentOrderStep.load(Bytes.fromUTF8(stepId));

  if (!entitySteps) {
    entitySteps = new FulfillmentOrderStep(Bytes.fromUTF8(stepId));
  }
  entitySteps.completedAt = step.completedAt;
  entitySteps.notes = step.notes;
  entitySteps.isCompleted = step.isCompleted;
  entitySteps.save();
}

export function handleFulfillmentCompleted(
  event: FulfillmentCompletedEvent
): void {
  let fulfillment = FGOFulfillment.bind(event.address);
  let data = fulfillment.getFulfillmentStatus(event.params.orderId);
  let marketAddress = fulfillment.market();
  let market = FGOMarket.bind(marketAddress);
  let orderData = market.getOrderReceipt(event.params.orderId);

  let isPhysical = orderData.params.isPhysical;

  let stepId =
    data.parentContract.toHexString() +
    "-" +
    data.parentId.toHexString() +
    "-" +
    (data.steps.length - 1).toString();

  if (isPhysical) {
    stepId = stepId + "-physical";
  }

  let entitySteps = FulfillmentOrderStep.load(Bytes.fromUTF8(stepId));
  if (entitySteps) {
    entitySteps.completedAt = data.steps[data.steps.length - 1].completedAt;
    entitySteps.isCompleted = data.steps[data.steps.length - 1].isCompleted;
    entitySteps.save();
  }

  let entityOrder = ChildOrder.load(
    Bytes.fromUTF8(
      marketAddress.toHexString() + "-" + event.params.orderId.toString()
    )
  );

  if (entityOrder) {
    let rec = market.getOrderReceipt(event.params.orderId);
    entityOrder.orderStatus = BigInt.fromI32(rec.status);
    entityOrder.save();
  }
}

export function handleFulfillmentStarted(event: FulfillmentStartedEvent): void {
  let fulfillment = FGOFulfillment.bind(event.address);
  let data = fulfillment.getFulfillmentStatus(event.params.orderId);

  let entity = new Fulfillment(
    Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.orderId.toString() +
        data.parentContract.toHexString() +
        event.params.parentId.toHexString()
    )
  );

  entity.orderId = event.params.orderId;
  entity.parent = Bytes.fromUTF8(
    data.parentContract.toHexString() + "-" + event.params.parentId.toString()
  );
  entity.currentStep = data.currentStep;
  entity.createdAt = event.block.timestamp;
  entity.lastUpdated = event.block.timestamp;
  entity.order = Bytes.fromUTF8(
    fulfillment.market().toHexString() + "-" + entity.orderId.toString()
  );

  entity.save();
}
