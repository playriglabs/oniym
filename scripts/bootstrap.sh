#!/usr/bin/env bash
#
# Bootstrap the Oniym dev environment.
# Run once after cloning.
#
# Prerequisites:
#   - Node.js 20+
#   - pnpm 9+
#   - Foundry (https://book.getfoundry.sh/getting-started/installation)

set -euo pipefail

blue() { printf "\033[34m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }
red() { printf "\033[31m%s\033[0m\n" "$1"; }

# --- Prereq checks ---
blue "→ Checking prerequisites..."

if ! command -v pnpm &> /dev/null; then
    red "✗ pnpm not found. Install: npm install -g pnpm"
    exit 1
fi

if ! command -v forge &> /dev/null; then
    red "✗ Foundry not found. Install: curl -L https://foundry.paradigm.xyz | bash && foundryup"
    exit 1
fi

green "✓ Prerequisites OK"

# --- JS/TS dependencies ---
blue "→ Installing JS dependencies (pnpm)..."
pnpm install
green "✓ pnpm install complete"

# --- Foundry dependencies ---
blue "→ Installing Foundry dependencies..."
cd contracts

if [ ! -d "lib/forge-std" ]; then
    forge install foundry-rs/forge-std --no-commit
fi

if [ ! -d "lib/openzeppelin-contracts" ]; then
    forge install OpenZeppelin/openzeppelin-contracts --no-commit
fi

green "✓ Foundry deps installed"

# --- Build & test ---
blue "→ Building contracts..."
forge build
green "✓ Contracts built"

blue "→ Running contract tests..."
forge test
green "✓ Contract tests pass"

cd ..

# --- Env setup ---
if [ ! -f .env ]; then
    blue "→ Creating .env from example..."
    cp .env.example .env
    green "✓ .env created (edit with your RPC URLs)"
fi

# --- Final ---
echo ""
green "═══════════════════════════════════"
green "  Oniym dev environment ready ✓"
green "═══════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Edit .env with your Base RPC URL"
echo "  2. Run 'pnpm test' to verify all workspaces"
echo "  3. See docs/roadmap.md for week-by-week plan"
