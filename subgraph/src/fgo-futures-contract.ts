import { BigInt, ByteArray, Bytes, log } from "@graphprotocol/graph-ts";
import {
  FuturesContractOpened as FuturesContractOpenedEvent,
  FuturesContractCancelled as FuturesContractCancelledEvent,
  FGOFuturesContract,
} from "../generated/FGOFuturesContract/FGOFuturesContract";
import {
  Child,
  EscrowedRight,
  FuturesContract,
  Order,
} from "../generated/schema";
import { Metadata as MetadataTemplate } from "../generated/templates";
import { FGOFuturesSettlement } from "../generated/FGOFuturesSettlement/FGOFuturesSettlement";

export function handleFuturesContractOpened(
  event: FuturesContractOpenedEvent
): void {
  let futuresId = Bytes.fromByteArray(
    ByteArray.fromBigInt(event.params.contractId)
  );

  let futures = FGOFuturesContract.bind(event.address);
  let data = futures.try_getFuturesContract(event.params.contractId);
  let entity = FuturesContract.load(futuresId);
  let rightsKey = futures.getContractIdToRightsKey(event.params.contractId);
  if (!data.reverted) {
    if (!entity) {
      entity = new FuturesContract(futuresId);
    }

    let bots: Bytes[] = [];
    for (let i = 0; i < data.value.trustedSettlementBots.length; i++) {
      bots.push(
        Bytes.fromUTF8(data.value.trustedSettlementBots[i].toHexString())
      );
    }
    entity.trustedSettlementBots = bots;
    entity.contractId = event.params.contractId;
    entity.marketOrderId = event.params.orderId;
    entity.childId = event.params.childId;
    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;
    entity.pricePerUnit = event.params.pricePerUnit;
    entity.childContract = event.params.childContract;
    entity.originalMarket = event.params.originalMarket;
    entity.originalHolder = event.params.originalHolder;
    entity.tokenId = data.value.tokenId;
    entity.futuresSettlementDate = data.value.futuresSettlementDate;
    let settlement = FGOFuturesSettlement.bind(futures.settlementContract());
    entity.maxSettlementDelay = settlement.getMaxSettlementDelay();
    entity.createdAt = data.value.createdAt;
    entity.settledAt = data.value.settledAt;
    entity.settlementRewardBPS = data.value.settlementRewardBPS;

    entity.uri = data.value.uri;

    let ipfsHash = (entity.uri as string).split("/").pop();
    if (entity != null) {
      entity.metadata = ipfsHash;
      MetadataTemplate.create(ipfsHash);
    }

    entity.escrowed = rightsKey;

    entity.isActive = data.value.isActive;
    entity.isSettled = data.value.isSettled;
    entity.quantity = data.value.quantity;

    if (entity.childContract && entity.childId) {
      let childId = Bytes.fromUTF8(
        (entity.childContract as Bytes).toHexString() +
          "-" +
          (entity.childId as BigInt).toHexString()
      );
      let childEntity = Child.load(childId);

      if (childEntity) {
        entity.child = childEntity.id;
        let futuresContracts = childEntity.futuresContracts;
        if (!futuresContracts) {
          futuresContracts = [];
        }
        futuresContracts.push(entity.id);
        childEntity.futuresContracts = futuresContracts;
        childEntity.save();
      }
    }

    let entityEscrow = EscrowedRight.load(rightsKey);

    if (entityEscrow) {
      entityEscrow.amountUsedForFutures =
        entityEscrow.amountUsedForFutures.plus(event.params.quantity);
      entityEscrow.futuresCreated = true;
      let contracts = entityEscrow.contracts;
      if (!contracts) {
        contracts = [];
      }
      contracts.push(entity.id);
      entityEscrow.contracts = contracts;
      entityEscrow.save();
    }
    entity.save();
  }
}

export function handleFuturesContractCancelled(
  event: FuturesContractCancelledEvent
): void {
  let entity = FuturesContract.load(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.contractId))
  );

  if (entity) {
    entity.isActive = false;
    entity.save();

    if (entity.orders) {
      for (let i = 0; i < (entity.orders as Bytes[]).length; i++) {
        let order = Order.load((entity.orders as Bytes[])[i]);
        if (order) {
          order.isActive = false;
          order.save();
        }
      }
    }

    if (entity.escrowed) {
      let escrow = EscrowedRight.load(entity.escrowed as Bytes);
      if (escrow) {
        escrow.amountUsedForFutures = escrow.amountUsedForFutures.minus(
          entity.quantity as BigInt
        );
        escrow.futuresCreated = false;
        escrow.save();
      }
    }
  }
}
