import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  FGOFulfillers,
  FulfillerCreated as FulfillerCreatedEvent,
  FulfillerUpdated as FulfillerUpdatedEvent,
  FulfillerWalletTransferred as FulfillerWalletTransferredEvent,
} from "../generated/templates/FGOFulfillers/FGOFulfillers";
import { Fulfiller } from "../generated/schema";
import { FulfillerMetadata as FulfillerMetadataTemplate } from "../generated/templates";

export function handleFulfillerCreated(event: FulfillerCreatedEvent): void {
  let fulfillerContract = FGOFulfillers.bind(event.address);
  let infraId = fulfillerContract.infraId();
  let fulfillerId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.params.fulfiller.toHexString()
  );
  
  let entity = Fulfiller.load(fulfillerId);

  if (!entity) {
    entity = new Fulfiller(fulfillerId);
  }

  entity.fulfiller = event.params.fulfiller;
  entity.fulfillerId = event.params.fulfillerId;


  entity.infraId = infraId;
  let profileResult = fulfillerContract.try_getFulfillerProfile(entity.fulfillerId as BigInt);
  if (!profileResult.reverted) {
    let profile = profileResult.value;
    entity.uri = profile.uri;


    if (entity.uri) {
      let ipfsHash = (entity.uri as string).split("/").pop();
      if (ipfsHash != null) {
        entity.metadata = ipfsHash;
        FulfillerMetadataTemplate.create(ipfsHash);
      }
    }
  } 

  entity.save();
}

export function handleFulfillerURIUpdated(event: FulfillerUpdatedEvent): void {
  let fulfillerContract = FGOFulfillers.bind(event.address);
  let infraId = fulfillerContract.infraId();
  let fulfillerId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Fulfiller.load(fulfillerId);

  if (entity) {
    let profileResult = fulfillerContract.try_getFulfillerProfile(entity.fulfillerId as BigInt);
    if (!profileResult.reverted) {
      let profile = profileResult.value;
      entity.uri = profile.uri;


      if (entity.uri) {
        let ipfsHash = (entity.uri as string).split("/").pop();
        if (ipfsHash != null) {
          entity.metadata = ipfsHash;
          FulfillerMetadataTemplate.create(ipfsHash);
        }
      }
    }

    entity.save();
  }
}

export function handleFulfillerWalletTransferred(
  event: FulfillerWalletTransferredEvent
): void {
  let fulfillerContract = FGOFulfillers.bind(event.address);
  let infraId = fulfillerContract.infraId();
  let fulfillerId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Fulfiller.load(fulfillerId);

  if (entity) {
    entity.fulfiller = event.params.newAddress;
    entity.save();
  }
}


