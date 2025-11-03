import { BigInt, ByteArray, Bytes, log } from "@graphprotocol/graph-ts";
import {
  Child,
  Fulfillment,
  FulfillmentOrderStep,
  FulfillmentWorkflow,
  FuturesContract,
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
        event.params.orderId.toString() +
        data.parentContract.toHexString() +
        data.parentId.toHexString()
    )
  );

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
  entitySteps.stepIndex = data.currentStep;
  entitySteps.save();

  if (entity) {
    entity.currentStep = data.currentStep;
    entity.lastUpdated = data.lastUpdated;

    let steps = entity.fulfillmentOrderSteps;
    if (!steps) {
      steps = [];
    }
    if (steps.indexOf(entitySteps.id) == -1) {
      steps.push(entitySteps.id);
    }
    entity.fulfillmentOrderSteps = steps;
    entity.save();
  }
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



  let entity =  Fulfillment.load(
    Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.orderId.toHexString() +
        data.parentContract.toHexString() +
        data.parentId.toHexString()
    )
  );

  if (entity) {
  let parent = Parent.load(
   entity.parent
  );


  if (parent) {
    for (let j = 0; j < parent.children.length; j++) {
      let childEntity = Child.load(parent.children[j]);

      if (childEntity && childEntity.futuresContracts) {
        for (
          let i = 0;
          i < (childEntity.futuresContracts as Bytes[]).length;
          i++
        ) {
          let futuresContract = FuturesContract.load(
            (childEntity.futuresContracts as Bytes[])[i]
          );

          if (futuresContract) {
            let marketOrderId = futuresContract.marketOrderId;

            if (marketOrderId !== null) {
              if ((marketOrderId as BigInt).equals(event.params.orderId)) {
                futuresContract.isFulfilled = true;
                futuresContract.save();
              } 
            }
          } 
        }
      } 
    }
  }}
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
    data.parentContract.toHexString() +
      "-" +
      event.params.parentId.toHexString()
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

