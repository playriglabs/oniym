import { ponder } from "ponder:registry";
import * as schema from "../ponder.schema";

ponder.on("ReverseRegistrar:ReverseClaimed", async ({ event, context }) => {
    const { addr, node } = event.args;

    await context.db
        .insert(schema.reverseRecord)
        .values({ id: addr, reverseNode: node, updatedAt: event.block.timestamp })
        .onConflictDoUpdate({ reverseNode: node, updatedAt: event.block.timestamp });
});
