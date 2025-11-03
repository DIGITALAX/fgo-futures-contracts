import { Bytes, DataSourceContext } from "@graphprotocol/graph-ts";
import {
  ChildContractDeployed as ChildContractDeployedEvent,
  TemplateContractDeployed as TemplateContractEvent,
  MarketContractDeployed as MarketContractDeployedEvent,
  InfrastructureDeployed as InfrastructureEvent,
  ParentContractDeployed as ParentContractDeployedEvent,
} from "../generated/FGOFactory/FGOFactory";
import {
  FGOChild,
  FGOFulfillers,
  FGOFulfillment,
  FGOMarket,
  FGOParent,
  FGOTemplateChild,
} from "../generated/templates";
import { FGOMarket as FGOMarketContract } from "../generated/templates/FGOMarket/FGOMarket";

export function handleChildContractDeployed(
  event: ChildContractDeployedEvent
): void {
  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOChild.createWithContext(event.params.childContract, context);
}

export function handleMarketContractDeployed(
  event: MarketContractDeployedEvent
): void {
  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOMarket.createWithContext(event.params.marketContract, context);
  let marketContract = FGOMarketContract.bind(event.params.marketContract);
  FGOFulfillment.createWithContext(marketContract.fulfillment(), context);
}

export function handleTemplateContractDeployed(
  event: TemplateContractEvent
): void {
  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOTemplateChild.createWithContext(event.params.templateContract, context);
}

export function handleInfrastructureDeployed(event: InfrastructureEvent): void {
  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOFulfillers.createWithContext(event.params.fulfillers, context);
}

export function handleParentContractDeployed(
  event: ParentContractDeployedEvent
): void {
  let context = new DataSourceContext();
  context.setBytes("infraId", event.params.infraId);
  FGOParent.createWithContext(event.params.parentContract, context);
}
