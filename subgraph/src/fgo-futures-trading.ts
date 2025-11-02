import { BigInt, ByteArray, Bytes } from "@graphprotocol/graph-ts";
import {
  FeesCollected as FeesCollectedEvent,
  FGOFuturesTrading,
  SellOrderCancelled as SellOrderCancelledEvent,
  SellOrderCreated as SellOrderCreatedEvent,
  SellOrderFilled as SellOrderFilledEvent,
  SellOrderQuantityUpdated as SellOrderQuantityUpdatedEvent,
} from "../generated/FGOFuturesTrading/FGOFuturesTrading";
import { Order, FuturesContract, Filler } from "../generated/schema";

export function handleSellOrderQuantityUpdated(
  event: SellOrderQuantityUpdatedEvent
): void {
  let entity = Order.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.orderId))
  );

  if (entity) {
    entity.quantity = entity.quantity.plus(event.params.additionalQuantity);
    entity.save();
  }
}

export function handleFeesCollected(event: FeesCollectedEvent): void {
  let entity = Order.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.orderId))
  );

  if (entity) {
    entity.settlementFee = event.params.settlementFee;
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
  let entity = Order.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.orderId))
  );

  let trading = FGOFuturesTrading.bind(event.address);
  let contractId = trading.getContractIdByToken(event.params.tokenId);
  let order = trading.getSellOrder(event.params.orderId);
  let futuresId = Bytes.fromByteArray(ByteArray.fromBigInt(contractId));

  if (!entity) {
    entity = new Order(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.orderId))
    );
    entity.contract = futuresId;
    entity.orderId = event.params.orderId;
    entity.pricePerUnit = event.params.pricePerUnit;
    entity.seller = event.params.seller;
    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;
    entity.quantity = BigInt.fromI32(0);
    let futuresEntity = FuturesContract.load(futuresId);

    if (!futuresEntity) {
      futuresEntity = new FuturesContract(futuresId);
    }

    let orders = futuresEntity.orders;

    if (!orders) {
      orders = [];
    }
    orders.push(entity.id);
    futuresEntity.orders = orders;

    futuresEntity.save();
  }

  entity.quantity = entity.quantity.plus(event.params.quantity);
  entity.filled = order.filled == entity.quantity;
  entity.isActive = order.isActive;

  entity.save();
}

export function handleSellOrderFilled(event: SellOrderFilledEvent): void {
  let entity = Order.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.orderId))
  );

  let trading = FGOFuturesTrading.bind(event.address);
  let order = trading.getSellOrder(event.params.orderId);
  if (entity) {
    if (entity.quantity.equals(order.filled)) {
      entity.filled = true;
      entity.isActive = false;
    }

    let fillers = entity.fillers;
    if (!fillers) {
      fillers = [];
    }

    let fillerEntity = new Filler(
      Bytes.fromUTF8(
        event.params.buyer.toHexString() +
          event.params.quantity.toHexString() +
          event.params.totalPrice.toHexString() +
          entity.orderId.toHexString()
      )
    );
    fillerEntity.order = entity.id;
    fillerEntity.price = event.params.totalPrice;
    fillerEntity.quantity = event.params.quantity;
    fillerEntity.filler = event.params.buyer;
    fillerEntity.blockNumber = event.block.number;
    fillerEntity.blockTimestamp = event.block.timestamp;
    fillerEntity.transactionHash = event.transaction.hash;

    fillerEntity.save();

    fillers.push(fillerEntity.id);
    entity.fillers = fillers;

    entity.save();
  }
}
