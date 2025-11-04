import {
  Address,
  BigInt,
  Bytes,
  store,
} from "@graphprotocol/graph-ts";
import {
  TemplateReserved as TemplateReservedEvent,
  ChildDeleted as ChildDeletedEvent,
  PhysicalRightsTransferred as PhysicalRightsTransferredEvent,
  ChildMinted as ChildMintedEvent,
  FGOTemplateChild,
} from "../generated/templates/FGOTemplateChild/FGOTemplateChild";
import { Child, PhysicalRights } from "../generated/schema";
import { Metadata as MetadataTemplate } from "../generated/templates";
import { FGOMarket } from "../generated/templates/FGOMarket/FGOMarket";
import { FGOChild } from "../generated/templates/FGOChild/FGOChild";

export function handleTemplateReserved(event: TemplateReservedEvent): void {
  let entityId = Bytes.fromUTF8(
    event.address.toHexString() + "-" + event.params.templateId.toHexString()
  );
  let entity = new Child(entityId);
  let template = FGOTemplateChild.bind(event.address);

  let childDataResult = template.try_getChildMetadata(event.params.templateId);

  if (childDataResult.reverted) {
    return;
  }

  let childData = childDataResult.value;

  entity.uri = childData.uri;

  entity.childContract = event.address;
  entity.childId = event.params.templateId;
  entity.physicalPrice = childData.physicalPrice;
  let ipfsHash = (entity.uri as string).split("/").pop();
  if (ipfsHash != null) {
    entity.metadata = ipfsHash;
    MetadataTemplate.create(ipfsHash);
  }

  entity.isTemplate = true;
  let placements: Bytes[] = [];
  let placementDataResult = template.try_getTemplatePlacements(
    event.params.templateId
  );

  if (!placementDataResult.reverted) {
    let placementData = placementDataResult.value;

    for (let i = 0; i < placementData.length; i++) {
      let placement = placementData[i];
      let placementChildId = Bytes.fromUTF8(
        placement.childContract.toHexString() +
          "-" +
          placement.childId.toHexString()
      );

      let placementChild = Child.load(placementChildId);

      if (placementChild) {
        placements.push(placementChild.id);
        if (placementChild.isTemplate) {
          placements = _getChildren(placements, placementChild);
        }
      }
    }
  }

  entity.placements = placements;

  entity.save();
}

export function handleChildDeleted(event: ChildDeletedEvent): void {
  let entity = Child.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toHexString()
    )
  );

  if (entity) {
    store.remove("Child", entity.id.toHexString());
  }
}

export function handlePhysicalRightsTransferred(
  event: PhysicalRightsTransferredEvent
): void {
  let senderRights = PhysicalRights.load(
    Bytes.fromUTF8(
      event.params.childId.toHexString() +
        "-" +
        event.address.toHexString() +
        "-" +
        event.params.orderId.toHexString() +
        "-" +
        event.params.sender.toHexString() +
        "-" +
        event.params.market.toHexString()
    )
  );

  let childContract = FGOChild.bind(event.address);
  if (senderRights) {
    senderRights.receiver = event.params.receiver;
    let senderAmount = childContract.getPhysicalRights(
      event.params.childId,
      event.params.orderId,
      event.params.sender,
      event.params.market
    );
    if (senderAmount.guaranteedAmount.equals(BigInt.fromI32(0))) {
      store.remove("PhysicalRights", senderRights.id.toHexString());
    } else {
      senderRights.guaranteedAmount = senderAmount.guaranteedAmount;
      senderRights.save();
    }
  }

  let receiverRights = PhysicalRights.load(
    Bytes.fromUTF8(
      event.params.childId.toHexString() +
        "-" +
        event.address.toHexString() +
        "-" +
        event.params.orderId.toHexString() +
        "-" +
        event.params.receiver.toHexString() +
        "-" +
        event.params.market.toHexString()
    )
  );

  let rights = childContract.getPhysicalRights(
    event.params.childId,
    event.params.orderId,
    event.params.receiver,
    event.params.market
  );

  if (!receiverRights) {
    receiverRights = new PhysicalRights(
      Bytes.fromUTF8(
        event.params.childId.toHexString() +
          "-" +
          event.address.toHexString() +
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
    receiverRights.estimatedDeliveryDuration = rights.estimatedDeliveryDuration;
    receiverRights.buyer = event.params.sender;
    let market = FGOMarket.bind(event.params.market);
    receiverRights.originalBuyer = market.getOrderReceipt(
      event.params.orderId
    ).buyer;
    receiverRights.blockTimestamp = event.block.timestamp;
    receiverRights.holder = event.params.receiver;
    receiverRights.guaranteedAmount = event.params.amount;
    receiverRights.purchaseMarket = event.params.market;
    receiverRights.order = Bytes.fromUTF8(
      event.params.market.toHexString() +
        "-" +
        event.params.orderId.toHexString()
    );
    receiverRights.child = Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.childId.toHexString()
    );
  } else {
    receiverRights.guaranteedAmount = rights.guaranteedAmount;
  }

  receiverRights.save();
}

function _getChildren(placements: Bytes[], placementChild: Child): Bytes[] {
  let template = FGOTemplateChild.bind(
    Address.fromBytes(placementChild.childContract)
  );
  let placementData = template.getTemplatePlacements(placementChild.childId);

  for (let i = 0; i < placementData.length; i++) {
    let placement = placementData[i];
    let placementChildId = Bytes.fromUTF8(
      placement.childContract.toHexString() +
        "-" +
        placement.childId.toHexString()
    );
    let placementChild = Child.load(placementChildId);

    if (placementChild) {
      placements.push(placementChild.id);
      if (placementChild.isTemplate) {
        placements = _getChildren(placements, placementChild);
      }
    }
  }

  return placements;
}
