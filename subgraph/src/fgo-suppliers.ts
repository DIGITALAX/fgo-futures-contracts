import {
  FGOSuppliers,
  SupplierDeactivated as SupplierDeactivatedEvent,
  SupplierReactivated as SupplierReactivatedEvent,
  SupplierCreated as SupplierCreatedEvent,
  SupplierUpdated as SupplierUpdatedEvent,
  SupplierWalletTransferred as SupplierWalletTransferredEvent,
} from "../generated/templates/FGOSuppliers/FGOSuppliers";
import { Supplier } from "../generated/schema";
import { SupplierMetadata as SupplierMetadataTemplate } from "../generated/templates";
import { BigInt, log, Bytes } from "@graphprotocol/graph-ts";

export function handleSupplierCreated(event: SupplierCreatedEvent): void {
  let supplierContract = FGOSuppliers.bind(event.address);
  let infraId = supplierContract.infraId();
  let supplierId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.params.supplier.toHexString()
  );

  let entity = Supplier.load(supplierId);

  if (!entity) {
    entity = new Supplier(supplierId);
  }

  entity.supplier = event.params.supplier;
  entity.supplierId = event.params.supplierId;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.infraId = infraId;

  let profileResult = supplierContract.try_getSupplierProfile(
    event.params.supplierId
  );
  if (!profileResult.reverted) {
    let profile = profileResult.value;
    entity.uri = profile.uri;
    entity.version = profile.version;
    entity.isActive = profile.isActive;

    if (entity.uri) {
      let ipfsHash = (entity.uri as string).split("/").pop();
      if (ipfsHash != null) {
        entity.metadata = ipfsHash;
        SupplierMetadataTemplate.create(ipfsHash);
      }
    }
  } else {
    entity.isActive = false;
  }

  entity.save();
}

export function handleSupplierURIUpdated(event: SupplierUpdatedEvent): void {
  let supplierContract = FGOSuppliers.bind(event.address);
  let infraId = supplierContract.infraId();
  let supplierId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Supplier.load(supplierId);

  if (entity) {
    let supplierIdFromEntity = entity.supplierId;
    if (supplierIdFromEntity) {
      let profileResult = supplierContract.try_getSupplierProfile(
        supplierIdFromEntity as BigInt
      );
      if (!profileResult.reverted) {
        let profile = profileResult.value;
        entity.uri = profile.uri;
        entity.version = profile.version;

        let uri = entity.uri;
        if (uri) {
          let ipfsHash = uri.split("/").pop();
          if (ipfsHash != null) {
            entity.metadata = ipfsHash;
            SupplierMetadataTemplate.create(ipfsHash);
          }
        }
      }
    }

    entity.save();
  }
}

export function handleSupplierWalletTransferred(
  event: SupplierWalletTransferredEvent
): void {
  let supplierContract = FGOSuppliers.bind(event.address);
  let infraId = supplierContract.infraId();
  let supplierId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Supplier.load(supplierId);

  if (entity) {
    entity.supplier = event.params.newAddress;
    entity.save();
  }
}

export function handleSupplierDeactivated(
  event: SupplierDeactivatedEvent
): void {
  let supplierContract = FGOSuppliers.bind(event.address);
  let infraId = supplierContract.infraId();
  let supplierId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Supplier.load(supplierId);

  if (entity) {
    entity.isActive = false;
    entity.save();
  }
}

export function handleSupplierReactivated(
  event: SupplierReactivatedEvent
): void {
  let supplierContract = FGOSuppliers.bind(event.address);
  let infraId = supplierContract.infraId();
  let supplierId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.transaction.from.toHexString()
  );
  let entity = Supplier.load(supplierId);

  if (entity) {
    entity.isActive = true;
    entity.save();
  }
}
