# 14 — AMM v3 Concentrated Liquidity & Tick Math

Motor de liquidez concentrada (arquitectura Uniswap v3): rangos de ticks, Q64.96, tick bitmap y swaps multi-tick. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–7** ✅ (módulo cerrado en alcance v1).

## Docs

Ver [`doc/`](./doc/README.md) — planificación, diagramas, SWC-AUDIT y gas.

## Tooling

```bash
# Usar Foundry real (no el `forge` de npm/nvm)
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
forge snapshot --match-contract CLPoolGasTest
```

## Deploy local

```bash
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: ver `.env.example` (`PRIVATE_KEY`, `FEE`, `INIT_TICK`).
