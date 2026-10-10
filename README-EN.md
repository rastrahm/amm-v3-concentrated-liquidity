# 14 — AMM v3 Concentrated Liquidity & Tick Math

Concentrated liquidity engine (Uniswap v3 architecture): tick ranges, Q64.96, tick bitmap, and multi-tick swaps. Solidity `0.8.24` + Foundry.

**Status:** Phases **0–7** ✅ (module closed within v1 scope).

## Docs

See [`doc/`](./doc/README-EN.md) — planning, diagrams, SWC-AUDIT, and gas.

## Tooling

```bash
# Use the real Foundry (not the npm/nvm `forge`)
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
forge snapshot --match-contract CLPoolGasTest
```

## Local deploy

```bash
anvil   # another terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: see `.env.example` (`PRIVATE_KEY`, `FEE`, `INIT_TICK`).
