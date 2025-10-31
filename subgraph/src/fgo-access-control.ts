import { Bytes } from "@graphprotocol/graph-ts";
import {
  FulfillerAdded as FulfillerAddedEvent,
  FGOAccessControl,
} from "../generated/templates/FGOAccessControl/FGOAccessControl";
import { Fulfiller } from "../generated/schema";

export function handleFulfillerAdded(event: FulfillerAddedEvent): void {
  let infraId = FGOAccessControl.bind(event.address).infraId();
  let fulfillerId = Bytes.fromUTF8(
    infraId.toHexString() + "-" + event.params.fulfiller.toHexString()
  );
  let fulfiller = new Fulfiller(fulfillerId);
  fulfiller.fulfiller = event.params.fulfiller;
  fulfiller.infraId = infraId;

  fulfiller.save();
}
