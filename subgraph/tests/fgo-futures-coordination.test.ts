import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Address, BigInt } from "@graphprotocol/graph-ts"
import { FuturesCreditsConsumed } from "../generated/schema"
import { FuturesCreditsConsumed as FuturesCreditsConsumedEvent } from "../generated/FGOFuturesCoordination/FGOFuturesCoordination"
import { handleFuturesCreditsConsumed } from "../src/fgo-futures-coordination"
import { createFuturesCreditsConsumedEvent } from "./fgo-futures-coordination-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let childContract = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let childId = BigInt.fromI32(234)
    let consumer = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let amount = BigInt.fromI32(234)
    let newFuturesCreditsConsumedEvent = createFuturesCreditsConsumedEvent(
      childContract,
      childId,
      consumer,
      amount
    )
    handleFuturesCreditsConsumed(newFuturesCreditsConsumedEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("FuturesCreditsConsumed created and stored", () => {
    assert.entityCount("FuturesCreditsConsumed", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "FuturesCreditsConsumed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "childContract",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "FuturesCreditsConsumed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "childId",
      "234"
    )
    assert.fieldEquals(
      "FuturesCreditsConsumed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "consumer",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "FuturesCreditsConsumed",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "amount",
      "234"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
