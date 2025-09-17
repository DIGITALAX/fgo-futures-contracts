import { ByteArray, Bytes } from "@graphprotocol/graph-ts";
import {
  FeesCollected as FeesCollectedEvent,
  FGOFuturesTrading,
  SellOrderCancelled as SellOrderCancelledEvent,
  SellOrderCreated as SellOrderCreatedEvent,
  SellOrderFilled as SellOrderFilledEvent,
} from "../generated/FGOFuturesTrading/FGOFuturesTrading";
import { Order, FuturesContract } from "../generated/schema";
import { FGOFuturesContract } from "../generated/FGOFuturesContract/FGOFuturesContract";

export function handleFeesCollected(event: FeesCollectedEvent): void {
  let entity = Order.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.orderId))
  );

  if (entity) {
    entity.protocolFee = event.params.protocolFee;
    entity.lpFee = event.params.lpFee;
    entity.save();
  }
}

export function handleSellOrderCancelled(event: SellOrderCancelledEvent): void {
  let entity = Order.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.orderId))
  );

  if (entity) {
    entity.isActive = false;
    entity.save();
  }
}

export function handleSellOrderCreated(event: SellOrderCreatedEvent): void {
  let entity = new Order(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.orderId))
  );
  let trading = FGOFuturesTrading.bind(event.address);
  let contractId = trading.getContractIdByToken(event.params.tokenId);

  let futuresId = Bytes.fromByteArray(ByteArray.fromBigInt(contractId));

  entity.orderId = event.params.orderId;
  entity.tokenId = event.params.tokenId;
  entity.quantity = event.params.quantity;
  entity.pricePerUnit = event.params.pricePerUnit;
  entity.seller = event.params.seller;
  entity.filled = false;
  entity.isActive = true;
  entity.contract = futuresId;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();

  let futuresEntity = FuturesContract.load(futuresId);

  if (futuresEntity) {
    let orders = futuresEntity.orders;

    if (!orders) {
      orders = [];
    }
    orders.push(entity.id);
    futuresEntity.orders = orders;

    futuresEntity.save();
  }
}

export function handleSellOrderFilled(event: SellOrderFilledEvent): void {
  let entity = Order.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.orderId))
  );

  if (entity) {
    entity.filled = true;
    entity.filledPrice = event.params.totalPrice;
    entity.filledQuantity = event.params.quantity;
    entity.filler = event.params.buyer;
    entity.save();
  }
}
