import { FuturesContractOpened as FuturesContractOpenedEvent } from "../generated/FGOFuturesContract/FGOFuturesContract"
import { FuturesContractOpened } from "../generated/schema"

export function handleFuturesContractOpened(
  event: FuturesContractOpenedEvent
): void {
  let entity = new FuturesContractOpened(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.contractId = event.params.contractId
  entity.childId = event.params.childId
  entity.orderId = event.params.orderId
  entity.quantity = event.params.quantity
  entity.pricePerUnit = event.params.pricePerUnit
  entity.childContract = event.params.childContract
  entity.originalMarket = event.params.originalMarket
  entity.originalHolder = event.params.originalHolder

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
