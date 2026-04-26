/* eslint-disable @typescript-eslint/no-unnecessary-condition */
/* eslint-disable @typescript-eslint/strict-boolean-expressions */
import { db } from "ponder:api";
import { Hono } from "hono";
import { eq, and } from "drizzle-orm";
import { Redis } from "ioredis";
import { isAddress, getAddress } from "viem";
import * as schema from "../../ponder.schema";

const redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6379", {
    lazyConnect: true,
    enableOfflineQueue: false,
});

const CACHE_TTL = 60; // seconds
const RATE_LIMIT_WINDOW = 60; // seconds
const RATE_LIMIT_MAX = 100; // requests per window

const app = new Hono();

// ---------------------------------------------------------------
//                        MIDDLEWARE
// ---------------------------------------------------------------

app.use("*", async (c, next) => {
    const ip = c.req.header("x-forwarded-for") ?? c.req.header("cf-connecting-ip") ?? "unknown";
    const key = `ratelimit:${ip}`;

    try {
        const count = await redis.incr(key);
        if (count === 1) await redis.expire(key, RATE_LIMIT_WINDOW);
        if (count > RATE_LIMIT_MAX) {
            return c.json({ error: "Rate limit exceeded" }, 429);
        }
    } catch {
        // Redis unavailable — allow the request through
    }

    await next();
});

// ---------------------------------------------------------------
//                          HELPERS
// ---------------------------------------------------------------

async function getCached<T>(key: string): Promise<T | null> {
    try {
        const raw = await redis.get(key);
        return raw != null ? (JSON.parse(raw) as T) : null;
    } catch {
        return null;
    }
}

async function setCache(key: string, value: unknown): Promise<void> {
    try {
        await redis.setex(key, CACHE_TTL, JSON.stringify(value));
    } catch {
        // ignore — cache is an optimisation, not a hard requirement
    }
}

function parseName(raw: string): { label: string; tld: string } | null {
    const parts = raw.split(".");
    if (parts.length !== 2 || parts[0].length === 0 || parts[1].length === 0) return null;
    return { label: parts[0].toLowerCase(), tld: parts[1].toLowerCase() };
}

// ---------------------------------------------------------------
//                           ROUTES
// ---------------------------------------------------------------

/**
 * Resolve a name to all its records.
 * GET /resolve/kyy.id
 */
app.get("/resolve/:name", async (c) => {
    const raw = c.req.param("name");
    const parsed = parseName(raw);
    if (!parsed) return c.json({ error: "Invalid name format. Expected label.tld" }, 400);

    const cacheKey = `resolve:${raw.toLowerCase()}`;
    const cached = await getCached<object>(cacheKey);
    if (cached) return c.json(cached);

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
    for (const r of addrs) addresses[r.coinType.toString()] = r.addr;

    const textMap: Record<string, string> = {};
    for (const r of texts) textMap[r.key] = r.value;

    const result = {
        name: nameRow.fullName,
        node: nameRow.id,
        owner: nameRow.owner,
        resolver: nameRow.resolver,
        expiresAt: nameRow.expiresAt.toString(),
        expired,
        addresses,
        texts: textMap,
        contenthash: contenthash?.contenthash ?? null,
    };

    if (!expired) await setCache(cacheKey, result);
    return c.json(result);
});

/**
 * Reverse lookup — address to claimed name.
 * GET /lookup/0x1234...
 *
 * NOTE: This returns the *claimed* name. Callers should verify forward
 * resolution matches before displaying it as a verified identity.
 */
app.get("/lookup/:address", async (c) => {
    const raw = c.req.param("address");
    if (!isAddress(raw)) return c.json({ error: "Invalid Ethereum address" }, 400);

    const address = getAddress(raw).toLowerCase() as `0x${string}`;
    const cacheKey = `lookup:${address}`;
    const cached = await getCached<object>(cacheKey);
    if (cached) return c.json(cached);

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
                    // addr is stored as raw hex bytes; last 40 chars = EVM address
                    const storedAddr = ethRecord.addr.slice(-40).toLowerCase();
                    verified = storedAddr === address.slice(2).toLowerCase();
                }
            }
        }
    }

    const result = {
        address: raw,
        name: claimedName,
        reverseNode: reverseRow.reverseNode,
        verified,
    };

    if (result.name) await setCache(cacheKey, result);
    return c.json(result);
});

/**
 * List all names owned by an address.
 * GET /names/0x1234...
 */
app.get("/names/:address", async (c) => {
    const raw = c.req.param("address");
    if (!isAddress(raw)) return c.json({ error: "Invalid Ethereum address" }, 400);

    const address = getAddress(raw).toLowerCase() as `0x${string}`;
    const cacheKey = `names:${address}`;
    const cached = await getCached<object>(cacheKey);
    if (cached) return c.json(cached);

    const now = BigInt(Math.floor(Date.now() / 1000));

    const rows = await db
        .select()
        .from(schema.name)
        .where(eq(schema.name.owner, address));

    const names = rows.map((r) => ({
        name: r.fullName,
        node: r.id,
        expiresAt: r.expiresAt.toString(),
        expired: r.expiresAt < now,
    }));

    const result = { address: raw, names };
    await setCache(cacheKey, result);
    return c.json(result);
});

export default app;
