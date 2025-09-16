import { newMockEvent } from "matchstick-as"
import { ethereum, BigInt, Address } from "@graphprotocol/graph-ts"
import {
  ContractSettled,
  MEVBotRegistered,
  MEVBotSlashed,
  StakeWithdrawn
} from "../generated/FGOFuturesMEV/FGOFuturesMEV"

export function createContractSettledEvent(
  contractId: BigInt,
  reward: BigInt,
  actualCompletionTime: BigInt,
  mevBot: Address
): ContractSettled {
  let contractSettledEvent = changetype<ContractSettled>(newMockEvent())

  contractSettledEvent.parameters = new Array()

  contractSettledEvent.parameters.push(
    new ethereum.EventParam(
      "contractId",
      ethereum.Value.fromUnsignedBigInt(contractId)
    )
  )
  contractSettledEvent.parameters.push(
    new ethereum.EventParam("reward", ethereum.Value.fromUnsignedBigInt(reward))
  )
  contractSettledEvent.parameters.push(
    new ethereum.EventParam(
      "actualCompletionTime",
      ethereum.Value.fromUnsignedBigInt(actualCompletionTime)
    )
  )
  contractSettledEvent.parameters.push(
    new ethereum.EventParam("mevBot", ethereum.Value.fromAddress(mevBot))
  )

  return contractSettledEvent
}

export function createMEVBotRegisteredEvent(
  stakeAmount: BigInt,
  bot: Address
): MEVBotRegistered {
  let mevBotRegisteredEvent = changetype<MEVBotRegistered>(newMockEvent())

  mevBotRegisteredEvent.parameters = new Array()

  mevBotRegisteredEvent.parameters.push(
    new ethereum.EventParam(
      "stakeAmount",
      ethereum.Value.fromUnsignedBigInt(stakeAmount)
    )
  )
  mevBotRegisteredEvent.parameters.push(
    new ethereum.EventParam("bot", ethereum.Value.fromAddress(bot))
  )

  return mevBotRegisteredEvent
}

export function createMEVBotSlashedEvent(
  slashAmount: BigInt,
  bot: Address
): MEVBotSlashed {
  let mevBotSlashedEvent = changetype<MEVBotSlashed>(newMockEvent())

  mevBotSlashedEvent.parameters = new Array()

  mevBotSlashedEvent.parameters.push(
    new ethereum.EventParam(
      "slashAmount",
      ethereum.Value.fromUnsignedBigInt(slashAmount)
    )
  )
  mevBotSlashedEvent.parameters.push(
    new ethereum.EventParam("bot", ethereum.Value.fromAddress(bot))
  )

  return mevBotSlashedEvent
}

export function createStakeWithdrawnEvent(
  amount: BigInt,
  bot: Address
): StakeWithdrawn {
  let stakeWithdrawnEvent = changetype<StakeWithdrawn>(newMockEvent())

  stakeWithdrawnEvent.parameters = new Array()

  stakeWithdrawnEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )
  stakeWithdrawnEvent.parameters.push(
    new ethereum.EventParam("bot", ethereum.Value.fromAddress(bot))
  )

  return stakeWithdrawnEvent
}
