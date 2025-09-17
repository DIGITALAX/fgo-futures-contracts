import { Bytes, dataSource, store } from "@graphprotocol/graph-ts";
import {
  ChildCreated as ChildCreatedEvent,
  ChildDeleted as ChildDeletedEvent,
  PhysicalRightsTransferred as PhysicalRightsTransferredEvent,
  ChildMinted as ChildMintedEvent,
  FGOChild,
} from "../generated/templates/FGOChild/FGOChild";
import { Child, PhysicalRights } from "../generated/schema";
import { Metadata as MetadataTemplate } from "../generated/templates";
import { FGOMarket } from "../generated/templates/FGOMarket/FGOMarket";

export function handleChildCreated(event: ChildCreatedEvent): void {
  let entityId = Bytes.fromUTF8(
    event.address.toHexString() + "-" + event.params.childId.toString()
  );
  let entity = new Child(entityId);
  let child = FGOChild.bind(event.address);
  let childData = child.getChildMetadata(event.params.childId);

  entity.uri = childData.uri;
  let context = dataSource.context();

  let template = context.getBytes("template");
  if (template == Bytes.fromI32(0)) {
    entity.isTemplate = false;
  } else {
    entity.isTemplate = true;
  }

  entity.childContract = event.address;
  entity.physicalPrice = childData.physicalPrice;
  let ipfsHash = (entity.uri as string).split("/").pop();
  if (ipfsHash != null) {
    entity.metadata = ipfsHash;
    MetadataTemplate.create(ipfsHash);
  }

  entity.save();
}

export function handleChildDeleted(event: ChildDeletedEvent): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    store.remove("Child", entity.id.toHexString());
  }
}

export function handleChildMinted(event: ChildMintedEvent): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    )
  );

  if (entity) {
    if (event.params.isPhysical) {
      let physicalRights = PhysicalRights.load(
        Bytes.fromUTF8(
          event.params.childId.toHexString() +
            "-" +
            event.params.orderId.toHexString() +
            "-" +
            event.params.to.toHexString() +
            "-" +
            event.params.market.toHexString()
        )
      );
      if (!physicalRights) {
        physicalRights = new PhysicalRights(
          Bytes.fromUTF8(
            event.params.childId.toHexString() +
              "-" +
              event.params.orderId.toHexString() +
              "-" +
              event.params.to.toHexString() +
              "-" +
              event.params.market.toHexString()
          )
        );
        physicalRights.childId = event.params.childId;
        physicalRights.orderId = event.params.orderId;
        physicalRights.buyer = event.params.to;
        physicalRights.child = entity.id;
        physicalRights.guaranteedAmount = event.params.amount;
        physicalRights.purchaseMarket = event.params.market;
        physicalRights.originalBuyer = event.params.to;
        physicalRights.order = Bytes.fromUTF8(
          event.params.market.toHexString() +
            "-" +
            event.params.orderId.toString()
        );
      } else {
        physicalRights.guaranteedAmount = physicalRights.guaranteedAmount.plus(
          event.params.amount
        );
      }
      physicalRights.save();
    }

    entity.save();
  }
}

export function handlePhysicalRightsTransferred(
  event: PhysicalRightsTransferredEvent
): void {
  let senderRights = PhysicalRights.load(
    Bytes.fromUTF8(
      event.params.childId.toHexString() +
        "-" +
        event.params.orderId.toHexString() +
        "-" +
        event.params.sender.toHexString() +
        "-" +
        event.params.market.toHexString()
    )
  );

  if (senderRights) {
    if (senderRights.guaranteedAmount.equals(event.params.amount)) {
      store.remove("PhysicalRights", senderRights.id.toString());
    } else {
      senderRights.guaranteedAmount = senderRights.guaranteedAmount.minus(
        event.params.amount
      );
      senderRights.save();
    }
  }

  let receiverRights = PhysicalRights.load(
    Bytes.fromUTF8(
      event.params.childId.toHexString() +
        "-" +
        event.params.orderId.toHexString() +
        "-" +
        event.params.receiver.toHexString() +
        "-" +
        event.params.market.toHexString()
    )
  );

  if (!receiverRights) {
    receiverRights = new PhysicalRights(
      Bytes.fromUTF8(
        event.params.childId.toHexString() +
          "-" +
          event.params.orderId.toHexString() +
          "-" +
          event.params.receiver.toHexString() +
          "-" +
          event.params.market.toHexString()
      )
    );
    receiverRights.childId = event.params.childId;
    receiverRights.orderId = event.params.orderId;
    receiverRights.buyer = event.params.sender;
    let market = FGOMarket.bind(event.params.market);
    receiverRights.originalBuyer = market.getOrderReceipt(
      event.params.orderId
    ).buyer;

    receiverRights.holder = event.params.receiver;
    receiverRights.guaranteedAmount = event.params.amount;
    receiverRights.purchaseMarket = event.params.market;
    receiverRights.order = Bytes.fromUTF8(
      event.params.market.toHexString() + "-" + event.params.orderId.toString()
    );
    receiverRights.child = Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toString()
    );
  } else {
    receiverRights.guaranteedAmount = receiverRights.guaranteedAmount.plus(
      event.params.amount
    );
  }

  receiverRights.save();
}
