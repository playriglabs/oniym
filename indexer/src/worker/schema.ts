import { pgTable, text, bigint, index, primaryKey } from "drizzle-orm/pg-core";

// Column names mirror Ponder's onchainTable — Ponder uses the JS property key as the SQL column name.

export const name = pgTable(
    "name",
    {
        id: text("id").primaryKey(),
        label: text("label").notNull(),
        tld: text("tld").notNull(),
        fullName: text("fullName").notNull(),
        owner: text("owner").notNull(),
        resolver: text("resolver"),
        expiresAt: bigint("expiresAt", { mode: "bigint" }).notNull(),
        registeredAt: bigint("registeredAt", { mode: "bigint" }).notNull(),
    },
    (table) => [
        index("name_owner_idx").on(table.owner),
        index("name_full_name_idx").on(table.fullName),
    ],
);

export const addrRecord = pgTable(
    "addr_record",
    {
        nameNode: text("nameNode").notNull(),
        coinType: bigint("coinType", { mode: "bigint" }).notNull(),
        addr: text("addr").notNull(),
        updatedAt: bigint("updatedAt", { mode: "bigint" }).notNull(),
    },
    (table) => [
        primaryKey({ columns: [table.nameNode, table.coinType] }),
        index("addr_name_node_idx").on(table.nameNode),
    ],
);

export const textRecord = pgTable(
    "text_record",
    {
        nameNode: text("nameNode").notNull(),
        key: text("key").notNull(),
        value: text("value").notNull(),
        updatedAt: bigint("updatedAt", { mode: "bigint" }).notNull(),
    },
    (table) => [
        primaryKey({ columns: [table.nameNode, table.key] }),
        index("text_name_node_idx").on(table.nameNode),
    ],
);

export const contenthashRecord = pgTable("contenthash_record", {
    id: text("id").primaryKey(),
    contenthash: text("contenthash").notNull(),
    updatedAt: bigint("updatedAt", { mode: "bigint" }).notNull(),
});

export const reverseRecord = pgTable("reverse_record", {
    id: text("id").primaryKey(),
    reverseNode: text("reverseNode").notNull(),
    updatedAt: bigint("updatedAt", { mode: "bigint" }).notNull(),
});
