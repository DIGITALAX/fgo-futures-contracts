import {
  Bytes,
  JSONValue,
  JSONValueKind,
  dataSource,
  json,
  log,
} from "@graphprotocol/graph-ts";
import { Metadata, FulfillerMetadata } from "../generated/schema";

function extractString(
  value: JSONValue | null,
  fieldName: string
): string | null {
  if (!value || value.kind !== JSONValueKind.STRING) {
    return null;
  }
  let stringValue = value.toString();
  if (stringValue.includes("base64")) {
    log.warning("Skipping base64 encoded field: {}", [fieldName]);
    return null;
  }
  return stringValue;
}

export function handleMetadata(content: Bytes): void {
  let entityId = dataSource.stringParam();
  const obj = json.fromString(content.toString()).toObject();
  if (!obj) {
    log.error("Failed to parse JSON for metadata: {}", [entityId]);
    return;
  }

  let metadata = new Metadata(entityId);

  let image = extractString(obj.get("image"), "image");
  if (image) metadata.image = image;

  let title = extractString(obj.get("title"), "title");
  if (title) metadata.title = title;

  metadata.save();
}

export function handleFulfillerMetadata(content: Bytes): void {
  let entityId = dataSource.stringParam();
  const obj = json.fromString(content.toString()).toObject();
  if (!obj) {
    log.error("Failed to parse JSON for fulfiller metadata: {}", [entityId]);
    return;
  }

  let metadata = new FulfillerMetadata(entityId);

  let image = extractString(obj.get("image"), "image");
  if (image) metadata.image = image;

  let title = extractString(obj.get("title"), "title");
  if (title) metadata.title = title;

  let link = extractString(obj.get("link"), "link");
  if (link) metadata.link = link;

  metadata.save();
}
