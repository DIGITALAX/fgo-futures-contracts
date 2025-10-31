import { Bytes, BigInt, dataSource } from "@graphprotocol/graph-ts";
import {
  ParentUpdated as ParentUpdatedEvent,
  FGOParent,
  ParentCreated as ParentCreatedEvent,
} from "../generated/templates/FGOParent/FGOParent";
import {
  FulfillmentStep,
  FulfillmentWorkflow,
  Parent,
  SubPerformer,
} from "../generated/schema";
import { Metadata as MetadataTemplate } from "../generated/templates";
import { FGOAccessControl } from "../generated/templates/FGOAccessControl/FGOAccessControl";

export function handleParentUpdated(event: ParentUpdatedEvent): void {
  let entity = Parent.load(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.designId.toHexString()
    )
  );

  if (entity) {
    let parent = FGOParent.bind(event.address);
    let data = parent.getDesignTemplate(entity.designId as BigInt);

    entity.uri = data.uri;

    let ipfsHash = (entity.uri as string).split("/").pop();
    if (ipfsHash != null) {
      entity.metadata = ipfsHash;
      MetadataTemplate.create(ipfsHash);
    }

    entity.save();
  }
}

export function handleParentCreated(event: ParentCreatedEvent): void {
  let entityId = Bytes.fromUTF8(
    event.address.toHexString() + "-" + event.params.designId.toHexString()
  );
  let entity = new Parent(entityId);

  let parent = FGOParent.bind(event.address);

  entity.designId = event.params.designId;
  entity.parentContract = event.address;

  let data = parent.getDesignTemplate(entity.designId as BigInt);
  let accessControl = parent.accessControl();
  let accessControlContract = FGOAccessControl.bind(accessControl);
   entity.uri = data.uri;

  let ipfsHash = (entity.uri as string).split("/").pop();
  if (ipfsHash != null) {
    entity.metadata = ipfsHash;
    MetadataTemplate.create(ipfsHash);
  }

  let fulfillmentWorkflow = new FulfillmentWorkflow(
    Bytes.fromUTF8(
      event.address.toHexString() + "-" + event.params.designId.toHexString()
    )
  );

  fulfillmentWorkflow.parent = entity.id;
  fulfillmentWorkflow.estimatedDeliveryDuration =
    data.workflow.estimatedDeliveryDuration;
  let physicalSteps: Bytes[] = [];
  for (let i = 0; i < data.workflow.physicalSteps.length; i++) {
    let step = new FulfillmentStep(
      Bytes.fromUTF8(
        event.address.toHexString() +
          "-" +
          event.params.designId.toHexString() +
          "-" +
          i.toString() +
          "-physical"
      )
    );

    step.workflow = fulfillmentWorkflow.id;
    step.primaryPerformer =  data.workflow.physicalSteps[i].primaryPerformer;
    step.instructions = data.workflow.physicalSteps[i].instructions;
    step.fulfiller = Bytes.fromUTF8(
      accessControlContract.infraId().toHexString() +
        "-" +
        data.workflow.physicalSteps[i].primaryPerformer.toHexString()
    );

    let subPerformers: Bytes[] = [];
    for (
      let j = 0;
      j < data.workflow.physicalSteps[i].subPerformers.length;
      j++
    ) {
      let subPerformer = new SubPerformer(
        Bytes.fromUTF8(
          event.address.toHexString() +
            "-" +
            event.params.designId.toHexString() +
            "-" +
            i.toString() +
            "-" +
            data.workflow.physicalSteps[i].subPerformers[
              j
            ].performer.toHexString() +
            "-physical"
        )
      );

      subPerformer.step = step.id;
      subPerformer.performer =
        data.workflow.physicalSteps[i].subPerformers[j].performer;
      subPerformer.splitBasisPoints =
        data.workflow.physicalSteps[i].subPerformers[j].splitBasisPoints;
      subPerformer.save();

      subPerformers.push(subPerformer.id);
    }

    step.subPerformers = subPerformers;

    physicalSteps.push(step.id);
    step.save();
  }

  fulfillmentWorkflow.physicalSteps = physicalSteps;
  fulfillmentWorkflow.save();

  entity.workflow = fulfillmentWorkflow.id;
  entity.save();
}
