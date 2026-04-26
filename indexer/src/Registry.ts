import { ponder } from "ponder:registry";
import * as schema from "../ponder.schema";

ponder.on("Registry:Transfer", async ({ event, context }) => {
  const { node, owner } = event.args;
  // Silently skip nodes we don't track (root, TLD nodes, reverse nodes)
  try {
    await context.db.update(schema.name, { id: node }).set({ owner });
  } catch {}
});

ponder.on("Registry:NewResolver", async ({ event, context }) => {
  const { node, resolver } = event.args;
  try {
    await context.db.update(schema.name, { id: node }).set({ resolver });
  } catch {}
});
