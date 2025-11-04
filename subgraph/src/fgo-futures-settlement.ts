import { Address, BigInt, ByteArray, Bytes } from "@graphprotocol/graph-ts";
import {
  ContractSettled as ContractSettledEvent,
  EmergencySettlement as EmergencySettlementEvent,
  FGOFuturesSettlement,
  SettlementBotRegistered as SettlementBotRegisteredEvent,
  SettlementBotSlashed as SettlementBotSlashedEvent,
  RewardSlashed as RewardSlashedEvent,
  StakeWithdrawn as StakeWithdrawnEvent,
  StakeIncreased as StakeIncreasedEvent,
} from "../generated/FGOFuturesSettlement/FGOFuturesSettlement";
import {
  ContractSettled,
  Filler,
  FuturesContract,
  Order,
  SettlementBot,
} from "../generated/schema";
import { FGOFuturesTrading } from "../generated/FGOFuturesTrading/FGOFuturesTrading";

export function handleContractSettled(event: ContractSettledEvent): void {
  let entity = new ContractSettled(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.contractId))
  );
  entity.contractId = event.params.contractId;
  entity.reward = event.params.reward;
  entity.futuresSettlementDate = event.block.timestamp;
  entity.blockNumber = event.block.number;
  entity.settlementBot = Bytes.fromUTF8(
    event.params.settlementBot.toHexString()
  );
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.settler = event.params.settlementBot;
  entity.emergency = false;
  entity.contract = Bytes.fromByteArray(
    ByteArray.fromBigInt(event.params.contractId)
  );

  let futureEntity = FuturesContract.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.contractId))
  );

  if (futureEntity) {
    futureEntity.settledContract = Bytes.fromByteArray(
      ByteArray.fromBigInt(event.params.contractId)
    );

    let settlement = FGOFuturesSettlement.bind(event.address);
    let fulfillerSettlement = futureEntity.fulfillerSettlement;
    if (fulfillerSettlement !== null) {
      futureEntity.timeSinceCompletion = event.block.timestamp.minus(
        fulfillerSettlement as BigInt
      );
    }
    futureEntity.isSettled = true;
    futureEntity.isActive = false;
    futureEntity.settledAt = event.block.timestamp;

    futureEntity.save();
    let trading = FGOFuturesTrading.bind(settlement.trading());

    let ordersList = futureEntity.orders;

    if (ordersList !== null) {
      let orders = ordersList as Array<Bytes>;
      let finalFillers: Bytes[] = [];
      let seenFillers = new Array<string>();

      for (let i = 0; i < orders.length; i++) {
        let orderEntity = Order.load(orders[i]);
        if (orderEntity) {
          let filledList = orderEntity.fillers;
          if (filledList) {
            for (let j = 0; j < filledList.length; j++) {
              let fillerEntity = Filler.load(filledList[j]);
              if (fillerEntity && fillerEntity.filler) {
                let fillerBytes = fillerEntity.filler as Bytes;
                let fillerAddress = Address.fromBytes(fillerBytes);
                let balance = trading.balanceOf(
                  fillerAddress,
                  futureEntity.tokenId as BigInt
                );
                if (balance.gt(BigInt.fromI32(0))) {
                  let fillerHex = fillerBytes.toHexString();
                  if (seenFillers.indexOf(fillerHex) == -1) {
                    seenFillers.push(fillerHex);
                    finalFillers.push(fillerBytes);
                  }
                }
              }
            }
          }
        }
      }
      entity.finalFillers = finalFillers;
    }
  }

  entity.save();

  let settlementEntity = SettlementBot.load(
    Bytes.fromUTF8(event.params.settlementBot.toHexString())
  );

  if (settlementEntity) {
    let contracts = settlementEntity.settledContracts;

    if (!contracts) {
      contracts = [];
    }

    contracts.push(
      Bytes.fromByteArray(ByteArray.fromBigInt(event.params.contractId))
    );

    settlementEntity.settledContracts = contracts;

    settlementEntity.save();
  }
}

export function handleSettlementBotRegistered(
  event: SettlementBotRegisteredEvent
): void {
  let entity = new SettlementBot(
    Bytes.fromUTF8(event.params.bot.toHexString())
  );

  let settlement = FGOFuturesSettlement.bind(event.address);
  let data = settlement.getSettlementBot(event.params.bot);

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.stakeAmount = data.monaStaked;
  entity.bot = event.params.bot;
  entity.totalSettlements = data.totalSettlements;
  entity.averageDelaySeconds = data.averageDelaySeconds;
  entity.totalSlashEvents = data.slashEvents;
  entity.totalAmountSlashed = BigInt.fromI32(0);
  entity.totalRewardSlashed = BigInt.fromI32(0);
  entity.save();
}

export function handleSettlementBotSlashed(
  event: SettlementBotSlashedEvent
): void {
  let entity = SettlementBot.load(
    Bytes.fromUTF8(event.params.bot.toHexString())
  );

  if (entity) {
    let settlement = FGOFuturesSettlement.bind(event.address);
    let data = settlement.getSettlementBot(event.params.bot);

    entity.totalSlashEvents = entity.totalSlashEvents.plus(BigInt.fromI32(1));
    entity.totalAmountSlashed = event.params.slashAmount;
    entity.stakeAmount = data.monaStaked;
    entity.save();
  }
}

export function handleRewardSlashed(event: RewardSlashedEvent): void {
  let entity = SettlementBot.load(
    Bytes.fromUTF8(event.params.bot.toHexString())
  );

  if (entity) {
    entity.totalRewardSlashed = entity.totalRewardSlashed.plus(
      event.params.slashAmount
    );
    entity.save();
  }
}

export function handleStakeWithdrawn(event: StakeWithdrawnEvent): void {
  let entity = SettlementBot.load(
    Bytes.fromUTF8(event.params.bot.toHexString())
  );

  if (entity) {
    let settlement = FGOFuturesSettlement.bind(event.address);
    let data = settlement.getSettlementBot(event.params.bot);

    entity.stakeAmount = data.monaStaked;
    entity.save();
  }
}

export function handleStakeIncreased(event: StakeIncreasedEvent): void {
  let id = Bytes.fromUTF8(event.params.bot.toHexString());
  let entity = SettlementBot.load(id);
  let settlement = FGOFuturesSettlement.bind(event.address);
  let data = settlement.getSettlementBot(event.params.bot);

  if (!entity) {
    entity = new SettlementBot(id);
    entity.bot = event.params.bot;
    entity.totalAmountSlashed = BigInt.fromI32(0);
    entity.totalSlashEvents = BigInt.fromI32(0);
    entity.totalSettlements = BigInt.fromI32(0);
    entity.averageDelaySeconds = BigInt.fromI32(0);
    entity.totalRewardSlashed = BigInt.fromI32(0);
  }

  entity.stakeAmount = data.monaStaked;
  entity.totalSettlements = data.totalSettlements;
  entity.averageDelaySeconds = data.averageDelaySeconds;
  entity.totalSlashEvents = data.slashEvents;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.save();
}

export function handleEmergencySettlement(
  event: EmergencySettlementEvent
): void {
  let entity = new ContractSettled(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.contractId))
  );
  entity.contractId = event.params.contractId;
  entity.reward = BigInt.fromI32(0);
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.settler = event.params.settler;
  entity.emergency = true;
  entity.contract = Bytes.fromByteArray(
    ByteArray.fromBigInt(event.params.contractId)
  );
  let futureEntity = FuturesContract.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.contractId))
  );

  if (futureEntity) {
    futureEntity.settledContract = Bytes.fromByteArray(
      ByteArray.fromBigInt(event.params.contractId)
    );

    let settlement = FGOFuturesSettlement.bind(event.address);
    futureEntity.maxSettlementDelay = settlement.getMaxSettlementDelay();

    let fulfillerSettlement = futureEntity.fulfillerSettlement;
    if (fulfillerSettlement !== null) {
      futureEntity.timeSinceCompletion = event.block.timestamp.minus(
        fulfillerSettlement as BigInt
      );
    }
    futureEntity.isSettled = true;
    futureEntity.isActive = false;
    futureEntity.settledAt = event.block.timestamp;

    futureEntity.save();

    let trading = FGOFuturesTrading.bind(settlement.trading());

    let ordersList = futureEntity.orders;

    if (ordersList !== null) {
      let orders = ordersList as Array<Bytes>;
      let finalFillers: Bytes[] = [];
      let seenFillers = new Array<string>();

      for (let i = 0; i < orders.length; i++) {
        let orderEntity = Order.load(orders[i]);
        if (orderEntity) {
          let filledList = orderEntity.fillers;
          if (filledList) {
            for (let j = 0; j < filledList.length; j++) {
              let fillerEntity = Filler.load(filledList[j]);
              if (fillerEntity && fillerEntity.filler) {
                let fillerBytes = fillerEntity.filler as Bytes;
                let fillerAddress = Address.fromBytes(fillerBytes);
                let balance = trading.balanceOf(
                  fillerAddress,
                  futureEntity.tokenId as BigInt
                );
                if (balance.gt(BigInt.fromI32(0))) {
                  let fillerHex = fillerBytes.toHexString();
                  if (seenFillers.indexOf(fillerHex) == -1) {
                    seenFillers.push(fillerHex);
                    finalFillers.push(fillerBytes);
                  }
                }
              }
            }
          }
        }
      }
      entity.finalFillers = finalFillers;
    }
  }
  entity.save();
}
