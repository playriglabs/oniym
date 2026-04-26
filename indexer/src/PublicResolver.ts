import { ponder } from "ponder:registry";
import * as schema from "../ponder.schema";

ponder.on("PublicResolver:AddrChanged", async ({ event, context }) => {
  const { node, coinType, addr } = event.args;

  await context.db
    .insert(schema.addrRecord)
    .values({
      nameNode: node,
      coinType,
      addr,
      updatedAt: event.block.timestamp,
    })
    .onConflictDoUpdate({
      target: [schema.addrRecord.nameNode, schema.addrRecord.coinType],
      set: { addr, updatedAt: event.block.timestamp },
    });
});

ponder.on("PublicResolver:TextChanged", async ({ event, context }) => {
  const { node, key, value } = event.args;

  await context.db
    .insert(schema.textRecord)
    .values({
      nameNode: node,
      key,
      value,
      updatedAt: event.block.timestamp,
    })
    .onConflictDoUpdate({
      target: [schema.textRecord.nameNode, schema.textRecord.key],
      set: { value, updatedAt: event.block.timestamp },
    });
});

ponder.on("PublicResolver:ContenthashChanged", async ({ event, context }) => {
  const { node, hash } = event.args;

  await context.db
    .insert(schema.contenthashRecord)
    .values({
      id: node,
      contenthash: hash,
      updatedAt: event.block.timestamp,
    })
    .onConflictDoUpdate({
      target: schema.contenthashRecord.id,
      set: { contenthash: hash, updatedAt: event.block.timestamp },
    });
});
