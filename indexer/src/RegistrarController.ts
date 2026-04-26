import { ponder } from "ponder:registry";
import { keccak256, encodePacked, type Hex } from "viem";
import * as schema from "../ponder.schema";
import { TLD_MAP } from "./tldMap";

function nameNode(tld: Hex, label: Hex): Hex {
  return keccak256(encodePacked(["bytes32", "bytes32"], [tld, label]));
}

ponder.on("RegistrarController:NameRegistered", async ({ event, context }) => {
  const { name: label, tld, label: labelHash, owner, expires } = event.args;

  const tldStr = TLD_MAP.get(tld) ?? tld; // fallback to raw bytes32 if TLD unknown
  const node = nameNode(tld, labelHash);
  const fullName = `${label}.${tldStr}`;

  await context.db
    .insert(schema.name)
    .values({
      id: node,
      label,
      tld: tldStr,
      fullName,
      owner,
      resolver: null,
      expiresAt: expires,
      registeredAt: event.block.timestamp,
    })
    .onConflictDoUpdate({
      target: schema.name.id,
      set: { owner, expiresAt: expires },
    });
});

ponder.on("RegistrarController:NameRenewed", async ({ event, context }) => {
  const { tld, label: labelHash, expires } = event.args;

  const node = nameNode(tld, labelHash);

  await context.db
    .update(schema.name)
    .set({ expiresAt: expires })
    .where(({ id }) => id === node);
});
