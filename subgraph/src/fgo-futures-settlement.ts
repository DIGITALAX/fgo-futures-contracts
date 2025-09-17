import { Address, BigInt, ByteArray, Bytes } from "@graphprotocol/graph-ts";
import {
  ContractSettled as ContractSettledEvent,
  EmergencySettlement as EmergencySettlementEvent,
  FGOFuturesSettlement,
  SettlementBotRegistered as SettlementBotRegisteredEvent,
  SettlementBotSlashed as SettlementBotSlashedEvent,
  StakeWithdrawn as StakeWithdrawnEvent,
} from "../generated/FGOFuturesSettlement/FGOFuturesSettlement";
import {
  ContractSettled,
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
  entity.actualCompletionTime = event.params.actualCompletionTime;
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

    futureEntity.save();
    let settlement = FGOFuturesSettlement.bind(event.address);
    let trading = FGOFuturesTrading.bind(settlement.trading());

    let orders = futureEntity.orders;

    if (orders) {
      let finalFillers: Bytes[] = [];
      let seenFillers = new Set<string>();

      for (let i = 0; i < orders.length; i++) {
        let orderEntity = Order.load(orders[i]);
        if (orderEntity) {
          if (orderEntity.filler) {
            let balance = trading.balanceOf(
              orderEntity.filler as Address,
              orderEntity.tokenId
            );
            if (balance.gt(BigInt.fromI32(0))) {
              let fillerHex = (orderEntity.filler as Bytes).toHexString();
              if (!seenFillers.has(fillerHex)) {
                seenFillers.add(fillerHex);
                finalFillers.push(orderEntity.filler as Bytes);
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

export function handleEmergencySettlement(
  event: EmergencySettlementEvent
): void {
  let entity = new ContractSettled(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.contractId))
  );
  entity.contractId = event.params.contractId;
  entity.reward = BigInt.fromI32(0);
  entity.actualCompletionTime = event.params.settlementTime;
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

    futureEntity.save();

    let settlement = FGOFuturesSettlement.bind(event.address);
    let trading = FGOFuturesTrading.bind(settlement.trading());

    let orders = futureEntity.orders;

    if (orders) {
      let finalFillers: Bytes[] = [];
      let seenFillers = new Set<string>();

      for (let i = 0; i < orders.length; i++) {
        let orderEntity = Order.load(orders[i]);
        if (orderEntity) {
          if (orderEntity.filler) {
            let balance = trading.balanceOf(
              orderEntity.filler as Address,
              orderEntity.tokenId
            );
            if (balance.gt(BigInt.fromI32(0))) {
              let fillerHex = (orderEntity.filler as Bytes).toHexString();
              if (!seenFillers.has(fillerHex)) {
                seenFillers.add(fillerHex);
                finalFillers.push(orderEntity.filler as Bytes);
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
