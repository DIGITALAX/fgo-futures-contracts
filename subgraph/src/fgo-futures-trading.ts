import {
  ChildClaimedAfterSettlement as ChildClaimedAfterSettlementEvent,
  RightsDeposited as RightsDepositedEvent,
  RightsWithdrawn as RightsWithdrawnEvent,
} from "../generated/FGOFuturesTrading/FGOFuturesTrading"
import {
  ChildClaimedAfterSettlement,
  RightsDeposited,
  RightsWithdrawn,
} from "../generated/schema"

export function handleChildClaimedAfterSettlement(
  event: ChildClaimedAfterSettlementEvent,
): void {
  let entity = new ChildClaimedAfterSettlement(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.contractId = event.params.contractId
  entity.claimer = event.params.claimer
  entity.quantity = event.params.quantity
  entity.childId = event.params.childId

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleRightsDeposited(event: RightsDepositedEvent): void {
  let entity = new RightsDeposited(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.rightsKey = event.params.rightsKey
  entity.depositor = event.params.depositor
  entity.childContract = event.params.childContract
  entity.originalMarket = event.params.originalMarket
  entity.childId = event.params.childId
  entity.orderId = event.params.orderId
  entity.amount = event.params.amount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleRightsWithdrawn(event: RightsWithdrawnEvent): void {
  let entity = new RightsWithdrawn(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.rightsKey = event.params.rightsKey
  entity.withdrawer = event.params.withdrawer
  entity.amount = event.params.amount

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
