import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  FuturesCreditsConsumed,
  FuturesPositionClosed,
  FuturesPositionCreated,
  FuturesPurchased,
  FuturesSellOrderCancelled,
  FuturesSellOrderCreated,
  FuturesSellOrderFilled,
  FuturesSettled
} from "../generated/FGOFuturesCoordination/FGOFuturesCoordination"

export function createFuturesCreditsConsumedEvent(
  childContract: Address,
  childId: BigInt,
  consumer: Address,
  amount: BigInt
): FuturesCreditsConsumed {
  let futuresCreditsConsumedEvent =
    changetype<FuturesCreditsConsumed>(newMockEvent())

  futuresCreditsConsumedEvent.parameters = new Array()

  futuresCreditsConsumedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresCreditsConsumedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresCreditsConsumedEvent.parameters.push(
    new ethereum.EventParam("consumer", ethereum.Value.fromAddress(consumer))
  )
  futuresCreditsConsumedEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return futuresCreditsConsumedEvent
}

export function createFuturesPositionClosedEvent(
  childContract: Address,
  childId: BigInt,
  supplier: Address
): FuturesPositionClosed {
  let futuresPositionClosedEvent =
    changetype<FuturesPositionClosed>(newMockEvent())

  futuresPositionClosedEvent.parameters = new Array()

  futuresPositionClosedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresPositionClosedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresPositionClosedEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )

  return futuresPositionClosedEvent
}

export function createFuturesPositionCreatedEvent(
  childContract: Address,
  childId: BigInt,
  supplier: Address,
  totalAmount: BigInt,
  pricePerUnit: BigInt,
  deadline: BigInt
): FuturesPositionCreated {
  let futuresPositionCreatedEvent =
    changetype<FuturesPositionCreated>(newMockEvent())

  futuresPositionCreatedEvent.parameters = new Array()

  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam("supplier", ethereum.Value.fromAddress(supplier))
  )
  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "totalAmount",
      ethereum.Value.fromUnsignedBigInt(totalAmount)
    )
  )
  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "pricePerUnit",
      ethereum.Value.fromUnsignedBigInt(pricePerUnit)
    )
  )
  futuresPositionCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "deadline",
      ethereum.Value.fromUnsignedBigInt(deadline)
    )
  )

  return futuresPositionCreatedEvent
}

export function createFuturesPurchasedEvent(
  childContract: Address,
  childId: BigInt,
  buyer: Address,
  amount: BigInt,
  totalCost: BigInt
): FuturesPurchased {
  let futuresPurchasedEvent = changetype<FuturesPurchased>(newMockEvent())

  futuresPurchasedEvent.parameters = new Array()

  futuresPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresPurchasedEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )
  futuresPurchasedEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )
  futuresPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "totalCost",
      ethereum.Value.fromUnsignedBigInt(totalCost)
    )
  )

  return futuresPurchasedEvent
}

export function createFuturesSellOrderCancelledEvent(
  childContract: Address,
  childId: BigInt,
  seller: Address,
  orderId: BigInt
): FuturesSellOrderCancelled {
  let futuresSellOrderCancelledEvent =
    changetype<FuturesSellOrderCancelled>(newMockEvent())

  futuresSellOrderCancelledEvent.parameters = new Array()

  futuresSellOrderCancelledEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresSellOrderCancelledEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresSellOrderCancelledEvent.parameters.push(
    new ethereum.EventParam("seller", ethereum.Value.fromAddress(seller))
  )
  futuresSellOrderCancelledEvent.parameters.push(
    new ethereum.EventParam(
      "orderId",
      ethereum.Value.fromUnsignedBigInt(orderId)
    )
  )

  return futuresSellOrderCancelledEvent
}

export function createFuturesSellOrderCreatedEvent(
  childContract: Address,
  childId: BigInt,
  seller: Address,
  orderId: BigInt,
  amount: BigInt,
  pricePerUnit: BigInt
): FuturesSellOrderCreated {
  let futuresSellOrderCreatedEvent =
    changetype<FuturesSellOrderCreated>(newMockEvent())

  futuresSellOrderCreatedEvent.parameters = new Array()

  futuresSellOrderCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresSellOrderCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresSellOrderCreatedEvent.parameters.push(
    new ethereum.EventParam("seller", ethereum.Value.fromAddress(seller))
  )
  futuresSellOrderCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "orderId",
      ethereum.Value.fromUnsignedBigInt(orderId)
    )
  )
  futuresSellOrderCreatedEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )
  futuresSellOrderCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "pricePerUnit",
      ethereum.Value.fromUnsignedBigInt(pricePerUnit)
    )
  )

  return futuresSellOrderCreatedEvent
}

export function createFuturesSellOrderFilledEvent(
  childContract: Address,
  childId: BigInt,
  seller: Address,
  buyer: Address,
  orderId: BigInt,
  amount: BigInt,
  totalCost: BigInt
): FuturesSellOrderFilled {
  let futuresSellOrderFilledEvent =
    changetype<FuturesSellOrderFilled>(newMockEvent())

  futuresSellOrderFilledEvent.parameters = new Array()

  futuresSellOrderFilledEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresSellOrderFilledEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresSellOrderFilledEvent.parameters.push(
    new ethereum.EventParam("seller", ethereum.Value.fromAddress(seller))
  )
  futuresSellOrderFilledEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )
  futuresSellOrderFilledEvent.parameters.push(
    new ethereum.EventParam(
      "orderId",
      ethereum.Value.fromUnsignedBigInt(orderId)
    )
  )
  futuresSellOrderFilledEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )
  futuresSellOrderFilledEvent.parameters.push(
    new ethereum.EventParam(
      "totalCost",
      ethereum.Value.fromUnsignedBigInt(totalCost)
    )
  )

  return futuresSellOrderFilledEvent
}

export function createFuturesSettledEvent(
  childContract: Address,
  childId: BigInt,
  buyer: Address,
  credits: BigInt
): FuturesSettled {
  let futuresSettledEvent = changetype<FuturesSettled>(newMockEvent())

  futuresSettledEvent.parameters = new Array()

  futuresSettledEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresSettledEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresSettledEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )
  futuresSettledEvent.parameters.push(
    new ethereum.EventParam(
      "credits",
      ethereum.Value.fromUnsignedBigInt(credits)
    )
  )

  return futuresSettledEvent
}
