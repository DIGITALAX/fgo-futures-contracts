import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { BigInt, Address } from "@graphprotocol/graph-ts"
import { FuturesContractOpened } from "../generated/schema"
import { FuturesContractOpened as FuturesContractOpenedEvent } from "../generated/FGOFuturesContract/FGOFuturesContract"
import { handleFuturesContractOpened } from "../src/fgo-futures-contract"
import { createFuturesContractOpenedEvent } from "./fgo-futures-contract-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let contractId = BigInt.fromI32(234)
    let childId = BigInt.fromI32(234)
    let orderId = BigInt.fromI32(234)
    let quantity = BigInt.fromI32(234)
    let pricePerUnit = BigInt.fromI32(234)
    let childContract = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let originalMarket = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let originalHolder = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let newFuturesContractOpenedEvent = createFuturesContractOpenedEvent(
      contractId,
      childId,
      orderId,
      quantity,
      pricePerUnit,
      childContract,
      originalMarket,
      originalHolder
    )
    handleFuturesContractOpened(newFuturesContractOpenedEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("FuturesContractOpened created and stored", () => {
    assert.entityCount("FuturesContractOpened", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "FuturesContractOpened",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "contractId",
      "234"
    )
    assert.fieldEquals(
      "FuturesContractOpened",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "childId",
      "234"
    )
    assert.fieldEquals(
      "FuturesContractOpened",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "orderId",
      "234"
    )
    assert.fieldEquals(
      "FuturesContractOpened",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "quantity",
      "234"
    )
    assert.fieldEquals(
      "FuturesContractOpened",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "pricePerUnit",
      "234"
    )
    assert.fieldEquals(
      "FuturesContractOpened",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "childContract",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "FuturesContractOpened",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "originalMarket",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "FuturesContractOpened",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "originalHolder",
      "0x0000000000000000000000000000000000000001"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
