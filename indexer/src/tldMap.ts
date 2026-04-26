import { keccak256, encodePacked, stringToBytes, type Hex } from "viem";

const ROOT = "0x0000000000000000000000000000000000000000000000000000000000000000" as Hex;

function tldNode(label: string): Hex {
  const labelHash = keccak256(stringToBytes(label));
  return keccak256(encodePacked(["bytes32", "bytes32"], [ROOT, labelHash]));
}

// tldNode (bytes32) → tld label string
export const TLD_MAP = new Map<Hex, string>([
  "id", "one", "me", "co", "xyz", "web3", "io", "pro", "app", "dev",
  "onm", "go", "ape", "fud", "hodl", "fomo", "moon", "rekt", "wagmi",
  "ngmi", "degen", "whale", "buidl", "dyor", "pump", "alpha", "safu",
  "l2", "gm", "lfg", "ser", "fren", "goat", "cope", "pepe", "wen",
  "mint", "bear", "gas", "dao", "ath", "dex", "cex", "burn", "node",
  "swap", "yield", "bag", "bags", "seed", "drop", "stake", "pool",
  "wrap", "farm", "shill", "xxx", "regs", "main", "test", "exit",
  "fair", "guh", "bots", "keys",
].map((label) => [tldNode(label), label]));
