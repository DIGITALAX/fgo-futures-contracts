import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  ApprovalForAll,
  FeesCollected,
  InitialPurchase,
  SellOrderCancelled,
  SellOrderCreated,
  SellOrderFilled,
  TransferBatch,
  TransferSingle,
  URI
} from "../generated/FGOFuturesTrading/FGOFuturesTrading"

export function createApprovalForAllEvent(
  account: Address,
  operator: Address,
  approved: boolean
): ApprovalForAll {
  let approvalForAllEvent = changetype<ApprovalForAll>(newMockEvent())

  approvalForAllEvent.parameters = new Array()

  approvalForAllEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )
  approvalForAllEvent.parameters.push(
    new ethereum.EventParam("operator", ethereum.Value.fromAddress(operator))
  )
  approvalForAllEvent.parameters.push(
    new ethereum.EventParam("approved", ethereum.Value.fromBoolean(approved))
  )

  return approvalForAllEvent
}

export function createFeesCollectedEvent(
  tokenId: BigInt,
  protocolFee: BigInt,
  lpFee: BigInt
): FeesCollected {
  let feesCollectedEvent = changetype<FeesCollected>(newMockEvent())

  feesCollectedEvent.parameters = new Array()

  feesCollectedEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )
  feesCollectedEvent.parameters.push(
    new ethereum.EventParam(
      "protocolFee",
      ethereum.Value.fromUnsignedBigInt(protocolFee)
    )
  )
  feesCollectedEvent.parameters.push(
    new ethereum.EventParam("lpFee", ethereum.Value.fromUnsignedBigInt(lpFee))
  )

  return feesCollectedEvent
}

export function createInitialPurchaseEvent(
  contractId: BigInt,
  tokenId: BigInt,
  quantity: BigInt,
  totalPrice: BigInt,
  buyer: Address
): InitialPurchase {
  let initialPurchaseEvent = changetype<InitialPurchase>(newMockEvent())

  initialPurchaseEvent.parameters = new Array()

  initialPurchaseEvent.parameters.push(
    new ethereum.EventParam(
      "contractId",
      ethereum.Value.fromUnsignedBigInt(contractId)
    )
  )
  initialPurchaseEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )
  initialPurchaseEvent.parameters.push(
    new ethereum.EventParam(
      "quantity",
      ethereum.Value.fromUnsignedBigInt(quantity)
    )
  )
  initialPurchaseEvent.parameters.push(
    new ethereum.EventParam(
      "totalPrice",
      ethereum.Value.fromUnsignedBigInt(totalPrice)
    )
  )
  initialPurchaseEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )

  return initialPurchaseEvent
}

export function createSellOrderCancelledEvent(
  orderId: BigInt,
  seller: Address
): SellOrderCancelled {
  let sellOrderCancelledEvent = changetype<SellOrderCancelled>(newMockEvent())

  sellOrderCancelledEvent.parameters = new Array()

  sellOrderCancelledEvent.parameters.push(
    new ethereum.EventParam(
      "orderId",
      ethereum.Value.fromUnsignedBigInt(orderId)
    )
  )
  sellOrderCancelledEvent.parameters.push(
    new ethereum.EventParam("seller", ethereum.Value.fromAddress(seller))
  )

  return sellOrderCancelledEvent
}

export function createSellOrderCreatedEvent(
  orderId: BigInt,
  tokenId: BigInt,
  quantity: BigInt,
  pricePerUnit: BigInt,
  seller: Address
): SellOrderCreated {
  let sellOrderCreatedEvent = changetype<SellOrderCreated>(newMockEvent())

  sellOrderCreatedEvent.parameters = new Array()

  sellOrderCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "orderId",
      ethereum.Value.fromUnsignedBigInt(orderId)
    )
  )
  sellOrderCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )
  sellOrderCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "quantity",
      ethereum.Value.fromUnsignedBigInt(quantity)
    )
  )
  sellOrderCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "pricePerUnit",
      ethereum.Value.fromUnsignedBigInt(pricePerUnit)
    )
  )
  sellOrderCreatedEvent.parameters.push(
    new ethereum.EventParam("seller", ethereum.Value.fromAddress(seller))
  )

  return sellOrderCreatedEvent
}

export function createSellOrderFilledEvent(
  orderId: BigInt,
  quantity: BigInt,
  totalPrice: BigInt,
  buyer: Address
): SellOrderFilled {
  let sellOrderFilledEvent = changetype<SellOrderFilled>(newMockEvent())

  sellOrderFilledEvent.parameters = new Array()

  sellOrderFilledEvent.parameters.push(
    new ethereum.EventParam(
      "orderId",
      ethereum.Value.fromUnsignedBigInt(orderId)
    )
  )
  sellOrderFilledEvent.parameters.push(
    new ethereum.EventParam(
      "quantity",
      ethereum.Value.fromUnsignedBigInt(quantity)
    )
  )
  sellOrderFilledEvent.parameters.push(
    new ethereum.EventParam(
      "totalPrice",
      ethereum.Value.fromUnsignedBigInt(totalPrice)
    )
  )
  sellOrderFilledEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )

  return sellOrderFilledEvent
}

export function createTransferBatchEvent(
  operator: Address,
  from: Address,
  to: Address,
  ids: Array<BigInt>,
  values: Array<BigInt>
): TransferBatch {
  let transferBatchEvent = changetype<TransferBatch>(newMockEvent())

  transferBatchEvent.parameters = new Array()

  transferBatchEvent.parameters.push(
    new ethereum.EventParam("operator", ethereum.Value.fromAddress(operator))
  )
  transferBatchEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  transferBatchEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  transferBatchEvent.parameters.push(
    new ethereum.EventParam("ids", ethereum.Value.fromUnsignedBigIntArray(ids))
  )
  transferBatchEvent.parameters.push(
    new ethereum.EventParam(
      "values",
      ethereum.Value.fromUnsignedBigIntArray(values)
    )
  )

  return transferBatchEvent
}

export function createTransferSingleEvent(
  operator: Address,
  from: Address,
  to: Address,
  id: BigInt,
  value: BigInt
): TransferSingle {
  let transferSingleEvent = changetype<TransferSingle>(newMockEvent())

  transferSingleEvent.parameters = new Array()

  transferSingleEvent.parameters.push(
    new ethereum.EventParam("operator", ethereum.Value.fromAddress(operator))
  )
  transferSingleEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  transferSingleEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  transferSingleEvent.parameters.push(
    new ethereum.EventParam("id", ethereum.Value.fromUnsignedBigInt(id))
  )
  transferSingleEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromUnsignedBigInt(value))
  )

  return transferSingleEvent
}

export function createURIEvent(value: string, id: BigInt): URI {
  let uriEvent = changetype<URI>(newMockEvent())

  uriEvent.parameters = new Array()

  uriEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromString(value))
  )
  uriEvent.parameters.push(
    new ethereum.EventParam("id", ethereum.Value.fromUnsignedBigInt(id))
  )

  return uriEvent
}
