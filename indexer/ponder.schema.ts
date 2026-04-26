import { index, onchainTable, primaryKey } from "ponder";

// Registered names — one row per name, updated on transfer/renewal
export const name = onchainTable(
  "name",
  (t) => ({
    id: t.hex().primaryKey(),       // nameNode (bytes32)
    label: t.text().notNull(),      // "kyy"
    tld: t.text().notNull(),        // "id"
    fullName: t.text().notNull(),   // "kyy.id"
    owner: t.hex().notNull(),
    resolver: t.hex(),
    expiresAt: t.bigint().notNull(),
    registeredAt: t.bigint().notNull(),
  }),
  (table) => ({
    ownerIdx: index().on(table.owner),
    fullNameIdx: index().on(table.fullName),
  }),
);

// Multichain address records — one row per (name, coinType)
export const addrRecord = onchainTable(
  "addr_record",
  (t) => ({
    nameNode: t.hex().notNull(),
    coinType: t.bigint().notNull(),
    addr: t.text().notNull(), // raw hex bytes (may be non-EVM)
    updatedAt: t.bigint().notNull(),
  }),
  (table) => ({
    pk: primaryKey({ columns: [table.nameNode, table.coinType] }),
    nameNodeIdx: index().on(table.nameNode),
  }),
);

// Text records — one row per (name, key)
export const textRecord = onchainTable(
  "text_record",
  (t) => ({
    nameNode: t.hex().notNull(),
    key: t.text().notNull(),
    value: t.text().notNull(),
    updatedAt: t.bigint().notNull(),
  }),
  (table) => ({
    pk: primaryKey({ columns: [table.nameNode, table.key] }),
    nameNodeIdx: index().on(table.nameNode),
  }),
);

// Contenthash — one row per name
export const contenthashRecord = onchainTable("contenthash_record", (t) => ({
  id: t.hex().primaryKey(), // nameNode
  contenthash: t.text().notNull(), // raw hex bytes
  updatedAt: t.bigint().notNull(),
}));

// Reverse records — one row per address that has claimed a reverse node
export const reverseRecord = onchainTable("reverse_record", (t) => ({
  id: t.hex().primaryKey(), // address
  reverseNode: t.hex().notNull(),
  updatedAt: t.bigint().notNull(),
}));
