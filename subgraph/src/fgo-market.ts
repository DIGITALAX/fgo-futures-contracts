import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  FGOMarket,
  OrderExecuted as OrderExecutedEvent,
} from "../generated/templates/FGOMarket/FGOMarket";
import { ChildOrder } from "../generated/schema";

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
  }
}
