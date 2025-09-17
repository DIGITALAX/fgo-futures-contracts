import { ByteArray, Bytes, store } from "@graphprotocol/graph-ts";
import {
  FuturesContractOpened as FuturesContractOpenedEvent,
  FuturesContractCancelled as FuturesContractCancelledEvent,
  FGOFuturesContract,
} from "../generated/FGOFuturesContract/FGOFuturesContract";
import {
  Child,
  EscrowedRight,
  FuturesContract,
  OrderToContract,
} from "../generated/schema";
import { Metadata as MetadataTemplate } from "../generated/templates";

export function handleFuturesContractOpened(
  event: FuturesContractOpenedEvent
): void {
  let entity = new FuturesContract(
    Bytes.fromByteArray(ByteArray.fromBigInt(event.params.contractId))
  );

  let futures = FGOFuturesContract.bind(event.address);
  let data = futures.getFuturesContract(event.params.contractId);

  entity.contractId = event.params.contractId;
  entity.childId = event.params.childId;
  entity.orderId = event.params.orderId;
  entity.quantity = event.params.quantity;
  entity.pricePerUnit = event.params.pricePerUnit;
  entity.childContract = event.params.childContract;
  entity.originalMarket = event.params.originalMarket;
  entity.originalHolder = event.params.originalHolder;
  entity.escrowed = futures.getContractIdToRightsKey(event.params.contractId);

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  let childEntity = Child.load(
    Bytes.fromUTF8(
      entity.childContract.toHexString() + "-" + entity.childId.toString()
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

  let orderLookup = new OrderToContract(
    Bytes.fromUTF8(
      event.params.childContract.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.params.orderId.toString() +
        "-" +
        event.params.originalMarket.toHexString()
    )
  );
  orderLookup.contractId = event.params.contractId;
  orderLookup.childId = event.params.childId;
  orderLookup.orderId = event.params.orderId;
  orderLookup.childContract = event.params.childContract;
  orderLookup.originalMarket = event.params.originalMarket;
  orderLookup.futuresContract = event.address as Bytes;
  orderLookup.save();

  entity.save();

  let rightsKey = futures.getContractIdToRightsKey(event.params.contractId);

  let entityEscrow = EscrowedRight.load(rightsKey);

  if (entityEscrow) {
    entityEscrow.amountUsedForFutures = event.params.quantity;
    entityEscrow.futuresCreated = true;
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
    let orderLookupId = Bytes.fromUTF8(
      entity.childContract.toHexString() +
        "-" +
        entity.childId.toString() +
        "-" +
        entity.orderId.toString() +
        "-" +
        entity.originalMarket.toHexString()
    );
    store.remove("OrderToContract", orderLookupId.toHexString());
    store.remove("FuturesContract", entity.id.toHexString());
  }
}
