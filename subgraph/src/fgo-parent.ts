import { Bytes, BigInt, dataSource } from "@graphprotocol/graph-ts";
import {
  ParentUpdated as ParentUpdatedEvent,
  FGOParent,
  ParentCreated as ParentCreatedEvent,
} from "../generated/templates/FGOParent/FGOParent";
import {
  Child,
  FulfillmentStep,
  FulfillmentWorkflow,
  Parent,
  SubPerformer,
} from "../generated/schema";
import { Metadata as MetadataTemplate } from "../generated/templates";
import { FGOAccessControl } from "../generated/templates/FGOAccessControl/FGOAccessControl";
import { FGOFulfillers } from "../generated/templates/FGOFulfillers/FGOFulfillers";

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
  let children: Bytes[] = [];
  for (let i = 0; i < data.childReferences.length; i++) {
    let childId = Bytes.fromUTF8(
      data.childReferences[i].childContract.toHexString() +
        "-" +
        data.childReferences[i].childId.toString()
    );
    let child = Child.load(childId);
    if (child) {
      children.push(child.id);
      if (child.isTemplate) {
        children = _loopChildren(children, child);
      }
    }
    // if (!child) {
    //   child = new Child(childId);
    //   child.childContract = data.childReferences[i].childContract;
    //   child.childId = data.childReferences[i].childId;
    //   child.isTemplate = true;
    //   child.futuresContracts = [];
    //   child.save();
    // }
  }
  entity.children = children;
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
    step.instructions = data.workflow.physicalSteps[i].instructions;

    data.workflow.physicalSteps[i].primaryPerformer;

    let fulfillers = FGOFulfillers.bind(
      parent.fulfillers()
    ).getFulfillerProfile(data.workflow.physicalSteps[i].primaryPerformer);
    let fulfillerId2 = Bytes.fromUTF8(
      accessControlContract.infraId().toHexString() +
        "-" +
        fulfillers.fulfillerAddress.toHexString()
    );

    step.fulfiller = fulfillerId2;

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

function _loopChildren(children: Bytes[], child: Child): Bytes[] {
  if (child.placements) {
    for (let i = 0; i < (child.placements as Bytes[]).length; i++) {
      let templateChild = Child.load((child.placements as Bytes[])[i]);
      if (templateChild) {
        if (templateChild.isTemplate) {
          children = _loopChildren(children, templateChild);
        }

        children.push(templateChild.id);
      }
    }
  }

  return children;
}
