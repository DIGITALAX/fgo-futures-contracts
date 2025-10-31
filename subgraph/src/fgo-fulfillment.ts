import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  Fulfillment,
  FulfillmentOrderStep,
  FulfillmentWorkflow,
  Order,
  Parent,
} from "../generated/schema";
import {
  StepCompleted as StepCompletedEvent,
  FulfillmentCompleted as FulfillmentCompletedEvent,
  FulfillmentStarted as FulfillmentStartedEvent,
  FGOFulfillment,
} from "../generated/templates/FGOFulfillment/FGOFulfillment";
import { FGOMarket } from "../generated/templates/FGOMarket/FGOMarket";

export function handleStepCompleted(event: StepCompletedEvent): void {
  let fulfillment = FGOFulfillment.bind(event.address);
  let data = fulfillment.getFulfillmentStatus(event.params.orderId);
  let entity = Fulfillment.load(
    Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.orderId.toHexString() +
        data.parentContract.toHexString() +
        data.parentId.toHexString()
    )
  );

  if (entity) {
    entity.currentStep = data.currentStep;
    entity.lastUpdated = data.lastUpdated;
    entity.save();
  }

  let step = data.steps[event.params.stepIndex.toI32()];

  let marketAddress = fulfillment.market();
  let market = FGOMarket.bind(marketAddress);
  let orderData = market.getOrderReceipt(event.params.orderId);

  let isPhysical = orderData.params.isPhysical;

  let stepId =
    data.parentContract.toHexString() +
    "-" +
    data.parentId.toHexString() +
    "-" +
    event.params.stepIndex.toHexString();

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



}

export function handleFulfillmentStarted(event: FulfillmentStartedEvent): void {
  let fulfillment = FGOFulfillment.bind(event.address);
  let data = fulfillment.getFulfillmentStatus(event.params.orderId);

  let entity = new Fulfillment(
    Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.orderId.toHexString() +
        data.parentContract.toHexString() +
        event.params.parentId.toHexString()
    )
  );

  entity.orderId = event.params.orderId;
  entity.parent = Bytes.fromUTF8(
    data.parentContract.toHexString() + "-" + event.params.parentId.toHexString()
  );
  let marketAddress = fulfillment.market();

  let market = FGOMarket.bind(marketAddress);

  let orderData = market.getOrderReceipt(event.params.orderId);
  entity.isPhysical = orderData.params.isPhysical;
  entity.currentStep = data.currentStep;
  entity.createdAt = event.block.timestamp;
  entity.lastUpdated = event.block.timestamp;
  entity.order = Bytes.fromUTF8(
    fulfillment.market().toHexString() + "-" + entity.orderId.toHexString()
  );

  entity.save();
}
