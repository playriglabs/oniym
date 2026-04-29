import { pgTable, text, bigint, index, primaryKey } from "drizzle-orm/pg-core";

// Column names mirror Ponder's onchainTable — Ponder uses the JS property key as the SQL column name.

export const name = pgTable(
    "name",
    {
        id: text("id").primaryKey(),
        label: text("label").notNull(),
        tld: text("tld").notNull(),
        fullName: text("full_name").notNull(),
        owner: text("owner").notNull(),
        resolver: text("resolver"),
        expiresAt: bigint("expires_at", { mode: "bigint" }).notNull(),
        registeredAt: bigint("registered_at", { mode: "bigint" }).notNull(),
    },
    (table) => [
        index("name_owner_idx").on(table.owner),
        index("name_full_name_idx").on(table.fullName),
    ],
);

export const addrRecord = pgTable(
    "addr_record",
    {
        nameNode: text("name_node").notNull(),
        coinType: bigint("coin_type", { mode: "bigint" }).notNull(),
        addr: text("addr").notNull(),
        updatedAt: bigint("updated_at", { mode: "bigint" }).notNull(),
    },
    (table) => [
        primaryKey({ columns: [table.nameNode, table.coinType] }),
        index("addr_name_node_idx").on(table.nameNode),
    ],
);

export const textRecord = pgTable(
    "text_record",
    {
        nameNode: text("name_node").notNull(),
        key: text("key").notNull(),
        value: text("value").notNull(),
        updatedAt: bigint("updated_at", { mode: "bigint" }).notNull(),
    },
    (table) => [
        primaryKey({ columns: [table.nameNode, table.key] }),
        index("text_name_node_idx").on(table.nameNode),
    ],
);

export const contenthashRecord = pgTable("contenthash_record", {
    id: text("id").primaryKey(),
    contenthash: text("contenthash").notNull(),
    updatedAt: bigint("updated_at", { mode: "bigint" }).notNull(),
});

export const reverseRecord = pgTable("reverse_record", {
    id: text("id").primaryKey(),
    reverseNode: text("reverse_node").notNull(),
    updatedAt: bigint("updated_at", { mode: "bigint" }).notNull(),
});
