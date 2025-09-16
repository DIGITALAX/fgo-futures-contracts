import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { BigInt, Address, Bytes } from "@graphprotocol/graph-ts"
import { ChildClaimedAfterSettlement } from "../generated/schema"
import { ChildClaimedAfterSettlement as ChildClaimedAfterSettlementEvent } from "../generated/FGOFuturesTrading/FGOFuturesTrading"
import { handleChildClaimedAfterSettlement } from "../src/fgo-futures-trading"
import { createChildClaimedAfterSettlementEvent } from "./fgo-futures-trading-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let contractId = BigInt.fromI32(234)
    let claimer = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let quantity = BigInt.fromI32(234)
    let childId = BigInt.fromI32(234)
    let newChildClaimedAfterSettlementEvent =
      createChildClaimedAfterSettlementEvent(
        contractId,
        claimer,
        quantity,
        childId
      )
    handleChildClaimedAfterSettlement(newChildClaimedAfterSettlementEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("ChildClaimedAfterSettlement created and stored", () => {
    assert.entityCount("ChildClaimedAfterSettlement", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "ChildClaimedAfterSettlement",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "contractId",
      "234"
    )
    assert.fieldEquals(
      "ChildClaimedAfterSettlement",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "claimer",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "ChildClaimedAfterSettlement",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "quantity",
      "234"
    )
    assert.fieldEquals(
      "ChildClaimedAfterSettlement",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "childId",
      "234"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
