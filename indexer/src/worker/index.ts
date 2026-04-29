import { Hono } from "hono";
import { cors } from "hono/cors";
import { eq, and } from "drizzle-orm";
import { neon } from "@neondatabase/serverless";
import { drizzle } from "drizzle-orm/neon-http";
import { isAddress, getAddress } from "viem";
import * as schema from "./schema";

export interface Env {
    DATABASE_URL: string;
    RATE_LIMIT: KVNamespace;
}

const RATE_LIMIT_WINDOW = 60;
const RATE_LIMIT_MAX = 100;

const HEX_ADDR_COIN_TYPES = new Set([60n, 714n, 784n]);

function decodeAddr(coinType: bigint, addr: string): string {
    if (HEX_ADDR_COIN_TYPES.has(coinType)) return addr;
    try {
        const hex = addr.startsWith("0x") ? addr.slice(2) : addr;
        const bytes = new Uint8Array((hex.match(/.{1,2}/g) ?? []).map((b) => parseInt(b, 16)));
        return new TextDecoder().decode(bytes);
    } catch {
        return addr;
    }
}

function parseName(raw: string): { label: string; tld: string } | null {
    const parts = raw.split(".");
    if (parts.length !== 2 || parts[0].length === 0 || parts[1].length === 0) return null;
    return { label: parts[0].toLowerCase(), tld: parts[1].toLowerCase() };
}

function createApp(env: Env) {
    const sql = neon(env.DATABASE_URL);
    const db = drizzle(sql, { schema });

    const app = new Hono<{ Bindings: Env }>();

    app.use("*", cors());

    app.use("*", async (c, next) => {
        const ip =
            c.req.header("cf-connecting-ip") ??
            c.req.header("x-forwarded-for") ??
            "unknown";
        const key = `ratelimit:${ip}`;
        try {
            const current = await env.RATE_LIMIT.get(key);
            const count = current ? parseInt(current) + 1 : 1;
            if (count > RATE_LIMIT_MAX) return c.json({ error: "Rate limit exceeded" }, 429);
            await env.RATE_LIMIT.put(key, String(count), { expirationTtl: RATE_LIMIT_WINDOW });
        } catch {
            // KV unavailable — allow through
        }
        await next();
    });

    // GET /resolve/:name
    app.get("/resolve/:name", async (c) => {
        const raw = c.req.param("name");
        const parsed = parseName(raw);
        if (!parsed) return c.json({ error: "Invalid name format. Expected label.tld" }, 400);

        const fullName = `${parsed.label}.${parsed.tld}`;

        const nameRow = await db
            .select()
            .from(schema.name)
            .where(eq(schema.name.fullName, fullName))
            .limit(1)
            .then((r) => r[0] ?? null);

        if (!nameRow) return c.json({ error: "Name not found" }, 404);

        const now = BigInt(Math.floor(Date.now() / 1000));
        const expired = nameRow.expiresAt < now;

        const [addrs, texts, contenthash] = await Promise.all([
            db.select().from(schema.addrRecord).where(eq(schema.addrRecord.nameNode, nameRow.id)),
            db.select().from(schema.textRecord).where(eq(schema.textRecord.nameNode, nameRow.id)),
            db
                .select()
                .from(schema.contenthashRecord)
                .where(eq(schema.contenthashRecord.id, nameRow.id))
                .limit(1)
                .then((r) => r[0] ?? null),
        ]);

        const addresses: Record<string, string> = {};
        for (const r of addrs) addresses[r.coinType.toString()] = decodeAddr(r.coinType, r.addr);

        const textMap: Record<string, string> = {};
        for (const r of texts) textMap[r.key] = r.value;

        return c.json({
            name: nameRow.fullName,
            node: nameRow.id,
            owner: nameRow.owner,
            resolver: nameRow.resolver,
            expiresAt: nameRow.expiresAt.toString(),
            expired,
            addresses,
            texts: textMap,
            contenthash: contenthash?.contenthash ?? null,
        });
    });

    // GET /lookup/:address
    app.get("/lookup/:address", async (c) => {
        const raw = c.req.param("address");
        if (!isAddress(raw)) return c.json({ error: "Invalid Ethereum address" }, 400);

        const address = getAddress(raw).toLowerCase() as `0x${string}`;

        const reverseRow = await db
            .select()
            .from(schema.reverseRecord)
            .where(eq(schema.reverseRecord.id, address))
            .limit(1)
            .then((r) => r[0] ?? null);

        if (!reverseRow) return c.json({ error: "No reverse record found" }, 404);

        const nameText = await db
            .select()
            .from(schema.textRecord)
            .where(
                and(
                    eq(schema.textRecord.nameNode, reverseRow.reverseNode),
                    eq(schema.textRecord.key, "name"),
                ),
            )
            .limit(1)
            .then((r) => r[0] ?? null);

        const claimedName = nameText?.value ?? null;

        let verified = false;
        if (claimedName) {
            const parsed = parseName(claimedName);
            if (parsed) {
                const nameRow = await db
                    .select()
                    .from(schema.name)
                    .where(eq(schema.name.fullName, claimedName))
                    .limit(1)
                    .then((r) => r[0] ?? null);

                if (nameRow) {
                    const ethRecord = await db
                        .select()
                        .from(schema.addrRecord)
                        .where(
                            and(
                                eq(schema.addrRecord.nameNode, nameRow.id),
                                eq(schema.addrRecord.coinType, 60n),
                            ),
                        )
                        .limit(1)
                        .then((r) => r[0] ?? null);

                    if (ethRecord) {
                        const storedAddr = ethRecord.addr.slice(-40).toLowerCase();
                        verified = storedAddr === address.slice(2).toLowerCase();
                    }
                }
            }
        }

        return c.json({
            address: raw,
            name: claimedName,
            reverseNode: reverseRow.reverseNode,
            verified,
        });
    });

    // GET /names/:address
    app.get("/names/:address", async (c) => {
        const raw = c.req.param("address");
        if (!isAddress(raw)) return c.json({ error: "Invalid Ethereum address" }, 400);

        const address = getAddress(raw).toLowerCase() as `0x${string}`;
        const now = BigInt(Math.floor(Date.now() / 1000));

        const rows = await db.select().from(schema.name).where(eq(schema.name.owner, address));

        const names = rows.map((r) => ({
            name: r.fullName,
            node: r.id,
            expiresAt: r.expiresAt.toString(),
            expired: r.expiresAt < now,
        }));

        return c.json({ address: raw, names });
    });

    return app;
}

export default {
    fetch(request: Request, env: Env, ctx: ExecutionContext): Response | Promise<Response> {
        return createApp(env).fetch(request, env, ctx);
    },
};
