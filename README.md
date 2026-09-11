# 14 — AMM v3 Concentrated Liquidity & Tick Math

Motor de liquidez concentrada (arquitectura Uniswap v3): rangos de ticks, Q64.96, tick bitmap y swaps multi-tick. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–5** ✅ (swap multi-tick). Fases **6–7** pendientes de autorización.

## Docs

Ver [`doc/`](./doc/README.md) — planificación, diagramas y flujogramas.

## Tooling

```bash
# Usar Foundry real (no el `forge` de npm/nvm)
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

## Próximo paso

Autorizar **Fase 6** (`CLFactory` + e2e / out-of-range / fuzz).
