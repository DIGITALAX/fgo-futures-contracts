import {
  Address,
  BigInt,
  ByteArray,
  Bytes,
  store,
} from "@graphprotocol/graph-ts";
import {
  ChildClaimedAfterSettlement as ChildClaimedAfterSettlementEvent,
  FGOFuturesEscrow,
  RightsDeposited as RightsDepositedEvent,
  RightsWithdrawn as RightsWithdrawnEvent,
} from "../generated/FGOFuturesEscrow/FGOFuturesEscrow";
import {
  ChildClaimed,
  EscrowedRight,
  FuturesContract,
  PhysicalRights,
} from "../generated/schema";
import { FGOChild } from "../generated/templates/FGOChild/FGOChild";

export function handleChildClaimedAfterSettlement(
  event: ChildClaimedAfterSettlementEvent
): void {
  let entity = new ChildClaimed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );

  entity.contractId = event.params.contractId;
  entity.claimer = event.params.claimer;
  entity.quantity = event.params.quantity;
  entity.childId = event.params.childId;
  let futuresId = Bytes.fromByteArray(
    ByteArray.fromBigInt(event.params.contractId)
  );
  entity.contract = futuresId;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();

  let futuresEntity = FuturesContract.load(futuresId);

  if (futuresEntity) {
    let claimed = futuresEntity.childrenClaimed;

    if (!claimed) {
      claimed = [];
    }
    claimed.push(entity.id);
    futuresEntity.childrenClaimed = claimed;
    futuresEntity.save();
  }
}

export function handleRightsDeposited(event: RightsDepositedEvent): void {
  let entity = new EscrowedRight(event.params.rightsKey);

  entity.rightsKey = event.params.rightsKey;
  entity.depositor = event.params.depositor;
  entity.childContract = event.params.childContract;
  entity.originalMarket = event.params.originalMarket;
  entity.childId = event.params.childId;
  entity.orderId = event.params.orderId;
  entity.amount = event.params.amount;
  let escrow = FGOFuturesEscrow.bind(event.address);
  entity.estimatedDeliveryDuration = escrow.getEscrowedRights(
    event.params.childId,
    event.params.orderId,
    event.params.childContract,
    event.params.originalMarket,
    event.params.depositor
  ).estimatedDeliveryDuration;
  entity.amountUsedForFutures = BigInt.fromI32(0);
  entity.depositedAt = event.block.timestamp;
  entity.futuresCreated = false;
  let entityId = Bytes.fromUTF8(
    event.params.childContract.toHexString() +
      "-" +
      event.params.childId.toHexString()
  );
  entity.child = entityId;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();

  let senderRights = PhysicalRights.load(
    Bytes.fromUTF8(
      event.params.childId.toHexString() +
        "-" +
        event.params.childContract.toHexString() +
        "-" +
        event.params.orderId.toHexString() +
        "-" +
        event.params.depositor.toHexString() +
        "-" +
        event.params.originalMarket.toHexString()
    )
  );

  if (senderRights && senderRights.receiver) {
    let receiverRights = PhysicalRights.load(
      Bytes.fromUTF8(
        event.params.childId.toHexString() +
          "-" +
          event.params.childContract.toHexString() +
          "-" +
          event.params.orderId.toHexString() +
          "-" +
          (senderRights.receiver as Bytes).toHexString() +
          "-" +
          event.params.originalMarket.toHexString()
      )
    );
    if (receiverRights) {
      let childContract = FGOChild.bind(event.params.childContract);

      let rights = childContract.getPhysicalRights(
        event.params.childId,
        event.params.orderId,
        Address.fromBytes(senderRights.receiver as Bytes),
        event.params.originalMarket
      );

      if (rights.guaranteedAmount.equals(event.params.amount)) {
        store.remove("PhysicalRights", receiverRights.id.toHexString());
      } else {
        receiverRights.guaranteedAmount = rights.guaranteedAmount;
        receiverRights.save();
      }
    }
  }
}

export function handleRightsWithdrawn(event: RightsWithdrawnEvent): void {
  let entity = EscrowedRight.load(event.params.rightsKey);

  if (entity) {
    let senderRights = PhysicalRights.load(
      Bytes.fromUTF8(
        entity.childId.toHexString() +
          "-" +
          entity.childContract.toHexString() +
          "-" +
          entity.orderId.toHexString() +
          "-" +
          event.params.withdrawer.toHexString() +
          "-" +
          entity.originalMarket.toHexString()
      )
    );

    if (senderRights) {
      let childContract = FGOChild.bind(
        Address.fromBytes(entity.childContract)
      );
      let rights = childContract.getPhysicalRights(
        entity.childId,
        entity.orderId,
        Address.fromBytes(event.params.withdrawer as Bytes),
        Address.fromBytes(entity.originalMarket)
      );

      senderRights.guaranteedAmount = rights.guaranteedAmount;
      senderRights.save();

      if (senderRights.receiver) {
        if (senderRights.receiver) {
          let receiverRights = PhysicalRights.load(
            Bytes.fromUTF8(
              entity.childId.toHexString() +
                "-" +
                entity.childContract.toHexString() +
                "-" +
                entity.orderId.toHexString() +
                "-" +
                (senderRights.receiver as Bytes).toHexString() +
                "-" +
                entity.originalMarket.toHexString()
            )
          );
          if (receiverRights) {
            let childContract = FGOChild.bind(
              Address.fromBytes(entity.childContract)
            );
            let rights = childContract.getPhysicalRights(
              entity.childId,
              entity.orderId,
              Address.fromBytes(senderRights.receiver as Bytes),
              Address.fromBytes(entity.originalMarket)
            );

            if (rights.guaranteedAmount.equals(event.params.amount)) {
              store.remove("PhysicalRights", receiverRights.id.toHexString());
            } else {
              receiverRights.guaranteedAmount = rights.guaranteedAmount;
              receiverRights.save();
            }
          }
        }
      }
    }

    store.remove("EscrowedRight", entity.id.toHexString());
  }
}
