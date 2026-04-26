import { ponder } from "ponder:registry";
import * as schema from "../ponder.schema";

ponder.on("Registry:Transfer", async ({ event, context }) => {
  const { node, owner } = event.args;

  // Update owner for any name we track; no-op if node is unknown (TLD/root nodes)
  await context.db
    .update(schema.name)
    .set({ owner })
    .where(({ id }) => id === node);
});

ponder.on("Registry:NewResolver", async ({ event, context }) => {
  const { node, resolver } = event.args;

  await context.db
    .update(schema.name)
    .set({ resolver })
    .where(({ id }) => id === node);
});
