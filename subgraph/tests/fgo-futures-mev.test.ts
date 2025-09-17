import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { BigInt, Address } from "@graphprotocol/graph-ts"
import { ContractSettled } from "../generated/schema"
import { ContractSettled as ContractSettledEvent } from "../generated/FGOFuturesMEV/FGOFuturesMEV"
import { handleContractSettled } from "../src/fgo-futures-settlement"
import { createContractSettledEvent } from "./fgo-futures-mev-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let contractId = BigInt.fromI32(234)
    let reward = BigInt.fromI32(234)
    let actualCompletionTime = BigInt.fromI32(234)
    let mevBot = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let newContractSettledEvent = createContractSettledEvent(
      contractId,
      reward,
      actualCompletionTime,
      mevBot
    )
    handleContractSettled(newContractSettledEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("ContractSettled created and stored", () => {
    assert.entityCount("ContractSettled", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "ContractSettled",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "contractId",
      "234"
    )
    assert.fieldEquals(
      "ContractSettled",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "reward",
      "234"
    )
    assert.fieldEquals(
      "ContractSettled",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "actualCompletionTime",
      "234"
    )
    assert.fieldEquals(
      "ContractSettled",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "mevBot",
      "0x0000000000000000000000000000000000000001"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
