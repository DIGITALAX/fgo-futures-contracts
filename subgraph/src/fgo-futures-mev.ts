import {
  ContractSettled as ContractSettledEvent,
  MEVBotRegistered as MEVBotRegisteredEvent,
  MEVBotSlashed as MEVBotSlashedEvent,
  StakeWithdrawn as StakeWithdrawnEvent,
} from "../generated/FGOFuturesMEV/FGOFuturesMEV"
import {
  ContractSettled,
  MEVBotRegistered,
  MEVBotSlashed,
  StakeWithdrawn,
} from "../generated/schema"

export function handleContractSettled(event: ContractSettledEvent): void {
  let entity = new ContractSettled(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.contractId = event.params.contractId
  entity.reward = event.params.reward
  entity.actualCompletionTime = event.params.actualCompletionTime
  entity.mevBot = event.params.mevBot

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleMEVBotRegistered(event: MEVBotRegisteredEvent): void {
  let entity = new MEVBotRegistered(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.stakeAmount = event.params.stakeAmount
  entity.bot = event.params.bot

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleMEVBotSlashed(event: MEVBotSlashedEvent): void {
  let entity = new MEVBotSlashed(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.slashAmount = event.params.slashAmount
  entity.bot = event.params.bot

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleStakeWithdrawn(event: StakeWithdrawnEvent): void {
  let entity = new StakeWithdrawn(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.amount = event.params.amount
  entity.bot = event.params.bot

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
