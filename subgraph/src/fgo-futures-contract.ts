import { BigInt, ByteArray, Bytes } from "@graphprotocol/graph-ts";
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

export function handleFuturesContractOpened(
  event: FuturesContractOpenedEvent
): void {
  let futuresId = Bytes.fromByteArray(
    ByteArray.fromBigInt(event.params.contractId)
  );

  let futures = FGOFuturesContract.bind(event.address);
  let data = futures.getFuturesContract(event.params.contractId);
  let entity = FuturesContract.load(futuresId);
  if (!entity) {
    entity = new FuturesContract(futuresId);
  }

  entity.contractId = event.params.contractId;
  entity.marketOrderId = event.params.orderId;
  entity.childId = event.params.childId;
  entity.isActive = data.isActive;
  entity.isSettled = data.isSettled;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.pricePerUnit = event.params.pricePerUnit;
  entity.childContract = event.params.childContract;
  entity.originalMarket = event.params.originalMarket;
  entity.originalHolder = event.params.originalHolder;
  entity.escrowed = futures.getContractIdToRightsKey(event.params.contractId);
  entity.tokenId = data.tokenId;
  entity.quantity = data.quantity;

  entity.futuresSettlementDate = data.futuresSettlementDate;

  let childEntity = Child.load(
    Bytes.fromUTF8(
      (entity.childContract as Bytes).toHexString() +
        "-" +
        (entity.childId as BigInt).toHexString()
    )
  );

  if (childEntity) {
    entity.child = childEntity.id;
  }

  entity.createdAt = data.createdAt;
  entity.settledAt = data.settledAt;
  entity.settlementRewardBPS = data.settlementRewardBPS;
  entity.isActive = data.isActive;
  entity.isSettled = data.isSettled;
  entity.uri = data.uri;

  let ipfsHash = (entity.uri as string).split("/").pop();
  if (entity != null) {
    entity.metadata = ipfsHash;
    MetadataTemplate.create(ipfsHash);
  }

  let settlements = data.trustedSettlementBots;
  let settlementData: Bytes[] = [];

  for (let i = 0; i < settlements.length; i++) {
    settlementData.push(Bytes.fromUTF8(settlements[i].toHexString()));
  }
  entity.trustedSettlementBots = settlementData;

  entity.save();

  let rightsKey = futures.getContractIdToRightsKey(event.params.contractId);

  let entityEscrow = EscrowedRight.load(rightsKey);

  if (entityEscrow) {
    entityEscrow.amountUsedForFutures = event.params.quantity;
    entityEscrow.futuresCreated = true;
    let contracts = entityEscrow.contracts;
    if (!contracts) {
      contracts = [];
    }
    contracts.push(entity.id);
    entityEscrow.contracts = contracts;
    entityEscrow.save();
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
        escrow.amountUsedForFutures = BigInt.fromI32(0);
        escrow.futuresCreated = false;
        escrow.save();
      }
    }
  }
}
