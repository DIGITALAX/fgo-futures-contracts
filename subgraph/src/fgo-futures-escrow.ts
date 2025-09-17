import { BigInt, ByteArray, Bytes, store } from "@graphprotocol/graph-ts";
import {
  ChildClaimedAfterSettlement as ChildClaimedAfterSettlementEvent,
  RightsDeposited as RightsDepositedEvent,
  RightsWithdrawn as RightsWithdrawnEvent,
} from "../generated/FGOFuturesEscrow/FGOFuturesEscrow";
import {
  ChildClaimed,
  EscrowedRight,
  FuturesContract,
} from "../generated/schema";

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
  entity.amountUsedForFutures = BigInt.fromI32(0);
  entity.depositedAt = event.block.timestamp;
  entity.futuresCreated = false;
  let entityId = Bytes.fromUTF8(
    event.params.childContract.toHexString() +
      "-" +
      event.params.childId.toString()
  );
  entity.child = entityId;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}

export function handleRightsWithdrawn(event: RightsWithdrawnEvent): void {
  let entity = EscrowedRight.load(event.params.rightsKey);

  if (entity) {
    store.remove("EscrowedRight", entity.id.toHexString());
  }
}
