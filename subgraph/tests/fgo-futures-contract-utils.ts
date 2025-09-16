import { newMockEvent } from "matchstick-as"
import { ethereum, BigInt, Address } from "@graphprotocol/graph-ts"
import { FuturesContractOpened } from "../generated/FGOFuturesContract/FGOFuturesContract"

export function createFuturesContractOpenedEvent(
  contractId: BigInt,
  childId: BigInt,
  orderId: BigInt,
  quantity: BigInt,
  pricePerUnit: BigInt,
  childContract: Address,
  originalMarket: Address,
  originalHolder: Address
): FuturesContractOpened {
  let futuresContractOpenedEvent =
    changetype<FuturesContractOpened>(newMockEvent())

  futuresContractOpenedEvent.parameters = new Array()

  futuresContractOpenedEvent.parameters.push(
    new ethereum.EventParam(
      "contractId",
      ethereum.Value.fromUnsignedBigInt(contractId)
    )
  )
  futuresContractOpenedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  futuresContractOpenedEvent.parameters.push(
    new ethereum.EventParam(
      "orderId",
      ethereum.Value.fromUnsignedBigInt(orderId)
    )
  )
  futuresContractOpenedEvent.parameters.push(
    new ethereum.EventParam(
      "quantity",
      ethereum.Value.fromUnsignedBigInt(quantity)
    )
  )
  futuresContractOpenedEvent.parameters.push(
    new ethereum.EventParam(
      "pricePerUnit",
      ethereum.Value.fromUnsignedBigInt(pricePerUnit)
    )
  )
  futuresContractOpenedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  futuresContractOpenedEvent.parameters.push(
    new ethereum.EventParam(
      "originalMarket",
      ethereum.Value.fromAddress(originalMarket)
    )
  )
  futuresContractOpenedEvent.parameters.push(
    new ethereum.EventParam(
      "originalHolder",
      ethereum.Value.fromAddress(originalHolder)
    )
  )

  return futuresContractOpenedEvent
}
