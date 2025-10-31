import { Address, BigInt, Bytes } from "@graphprotocol/graph-ts";
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
import { FGOParent } from "../generated/templates/FGOParent/FGOParent";
import { FGOAccessControl } from "../generated/templates/FGOAccessControl/FGOAccessControl";

export function handleOrderExecuted(event: OrderExecutedEvent): void {
  for (let i = 0; i < event.params.orderIds.length; i++) {
    let currentOrder = event.params.orderIds[i];

    let market = FGOMarket.bind(event.address);
    let data = market.getOrderReceipt(currentOrder);

    if (!data.params.parentId) return;

    let entity = new ChildOrder(
      Bytes.fromUTF8(
        event.address.toHexString() + "-" + currentOrder.toHexString()
      )
    );

    entity.orderStatus = BigInt.fromI32(data.status);
    entity.parent = Bytes.fromUTF8(
      data.params.parentContract.toHexString() +
        "-" +
        data.params.parentId.toHexString()
    );

    entity.fulfillment = Bytes.fromUTF8(
      market.getFulfillmentContract().toHexString() +
        "-" +
        currentOrder.toHexString() +
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
            let addedToFulfillers: string[] = [];

            for (
              let i = 0;
              i < (workflow.physicalSteps as Bytes[]).length;
              i++
            ) {
              let step = FulfillmentStep.load(
                Bytes.fromUTF8(
                  data.params.parentContract.toHexString() +
                    "-" +
                    data.params.parentId.toHexString() +
                    "-" +
                    i.toString() +
                    "-physical"
                )
              );
              if (step && step.fulfiller) {
                let fulfillerId = step.fulfiller as Bytes;
                let fulfillerHex = fulfillerId.toHexString();
                if (addedToFulfillers.indexOf(fulfillerHex) == -1) {
                  addedToFulfillers.push(fulfillerHex);

                  let fulfiller = Fulfiller.load(fulfillerId);
                  if (!fulfiller) {
                    fulfiller = new Fulfiller(fulfillerId);
                    if (parent.parentContract) {
                      let parentContractAddress = Address.fromBytes(
                        parent.parentContract as Bytes
                      );
                      let parentContract =
                        FGOParent.bind(parentContractAddress);
                      let accessControlContract = FGOAccessControl.bind(
                        parentContract.accessControl()
                      );
                      fulfiller.infraId = accessControlContract.infraId();
                    }
                  }

                  let childOrders = fulfiller.childOrders;

                  if (!childOrders) {
                    childOrders = [];
                  }
                  childOrders.push(entity.id);

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
