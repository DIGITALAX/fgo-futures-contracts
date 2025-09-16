import { newMockEvent } from "matchstick-as"
import { ethereum, BigInt, Address, Bytes } from "@graphprotocol/graph-ts"
import {
  ChildClaimedAfterSettlement,
  RightsDeposited,
  RightsWithdrawn
} from "../generated/FGOFuturesEscrow/FGOFuturesEscrow"

export function createChildClaimedAfterSettlementEvent(
  contractId: BigInt,
  claimer: Address,
  quantity: BigInt,
  childId: BigInt
): ChildClaimedAfterSettlement {
  let childClaimedAfterSettlementEvent =
    changetype<ChildClaimedAfterSettlement>(newMockEvent())

  childClaimedAfterSettlementEvent.parameters = new Array()

  childClaimedAfterSettlementEvent.parameters.push(
    new ethereum.EventParam(
      "contractId",
      ethereum.Value.fromUnsignedBigInt(contractId)
    )
  )
  childClaimedAfterSettlementEvent.parameters.push(
    new ethereum.EventParam("claimer", ethereum.Value.fromAddress(claimer))
  )
  childClaimedAfterSettlementEvent.parameters.push(
    new ethereum.EventParam(
      "quantity",
      ethereum.Value.fromUnsignedBigInt(quantity)
    )
  )
  childClaimedAfterSettlementEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )

  return childClaimedAfterSettlementEvent
}

export function createRightsDepositedEvent(
  rightsKey: Bytes,
  depositor: Address,
  childContract: Address,
  originalMarket: Address,
  childId: BigInt,
  orderId: BigInt,
  amount: BigInt
): RightsDeposited {
  let rightsDepositedEvent = changetype<RightsDeposited>(newMockEvent())

  rightsDepositedEvent.parameters = new Array()

  rightsDepositedEvent.parameters.push(
    new ethereum.EventParam(
      "rightsKey",
      ethereum.Value.fromFixedBytes(rightsKey)
    )
  )
  rightsDepositedEvent.parameters.push(
    new ethereum.EventParam("depositor", ethereum.Value.fromAddress(depositor))
  )
  rightsDepositedEvent.parameters.push(
    new ethereum.EventParam(
      "childContract",
      ethereum.Value.fromAddress(childContract)
    )
  )
  rightsDepositedEvent.parameters.push(
    new ethereum.EventParam(
      "originalMarket",
      ethereum.Value.fromAddress(originalMarket)
    )
  )
  rightsDepositedEvent.parameters.push(
    new ethereum.EventParam(
      "childId",
      ethereum.Value.fromUnsignedBigInt(childId)
    )
  )
  rightsDepositedEvent.parameters.push(
    new ethereum.EventParam(
      "orderId",
      ethereum.Value.fromUnsignedBigInt(orderId)
    )
  )
  rightsDepositedEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return rightsDepositedEvent
}

export function createRightsWithdrawnEvent(
  rightsKey: Bytes,
  withdrawer: Address,
  amount: BigInt
): RightsWithdrawn {
  let rightsWithdrawnEvent = changetype<RightsWithdrawn>(newMockEvent())

  rightsWithdrawnEvent.parameters = new Array()

  rightsWithdrawnEvent.parameters.push(
    new ethereum.EventParam(
      "rightsKey",
      ethereum.Value.fromFixedBytes(rightsKey)
    )
  )
  rightsWithdrawnEvent.parameters.push(
    new ethereum.EventParam(
      "withdrawer",
      ethereum.Value.fromAddress(withdrawer)
    )
  )
  rightsWithdrawnEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return rightsWithdrawnEvent
}
