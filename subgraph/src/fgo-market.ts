import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  FGOMarket,
  OrderExecuted as OrderExecutedEvent,
} from "../generated/templates/FGOMarket/FGOMarket";
import {
  ChildOrder,
  Fulfiller,
  FulfillmentStep,
  FulfillmentWorkflow,
  Parent,
} from "../generated/schema";

export function handleOrderExecuted(event: OrderExecutedEvent): void {
  for (let i = 0; i < event.params.orderIds.length; i++) {
    let currentOrder = event.params.orderIds[i];

    let market = FGOMarket.bind(event.address);
    let data = market.getOrderReceipt(currentOrder);

    if (!data.params.parentId) return;

    let entity = new ChildOrder(
      Bytes.fromUTF8(
        event.address.toHexString() + "-" + currentOrder.toString()
      )
    );

    entity.orderStatus = BigInt.fromI32(data.status);
    entity.parent = Bytes.fromUTF8(
      data.params.parentContract.toHexString() +
        "-" +
        data.params.parentId.toString()
    );

    entity.fulfillment = Bytes.fromUTF8(
      market.getFulfillmentContract().toHexString() +
        "-" +
        currentOrder.toString() +
        data.params.parentContract.toHexString() +
        data.params.parentId.toHexString()
    );

    entity.save();

    let parent = Parent.load(entity.parent as Bytes);
    if (parent) {
      if (parent.workflow) {
        let workflow = FulfillmentWorkflow.load(parent.workflow as Bytes);
        if (workflow) {
          if (workflow.physicalSteps) {
            let addedToFulfillers = new Set<string>();

            for (
              let i = 0;
              i < (workflow.physicalSteps as Bytes[]).length;
              i++
            ) {
              let step = FulfillmentStep.load(
                Bytes.fromUTF8(
                  data.params.parentContract.toHexString() +
                    "-" +
                    data.params.parentId.toString() +
                    "-" +
                    i.toString() +
                    "-physical"
                )
              );
              if (step && step.fulfiller) {
                let fulfillerHex = (step.fulfiller as Bytes).toHexString();
                if (!addedToFulfillers.has(fulfillerHex)) {
                  addedToFulfillers.add(fulfillerHex);

                  let fulfiller = Fulfiller.load(step.fulfiller as Bytes);
                  if (fulfiller) {
                    let childOrders = fulfiller.childOrders;

                    if (!childOrders) {
                      childOrders = [];
                    }
                    childOrders.push(
                      Bytes.fromUTF8(
                        event.address.toHexString() +
                          "-" +
                          currentOrder.toString()
                      )
                    );
                    fulfiller.childOrders = childOrders;
                    fulfiller.save();
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
