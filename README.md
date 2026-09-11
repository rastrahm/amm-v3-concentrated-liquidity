# 14 — AMM v3 Concentrated Liquidity & Tick Math

Motor de liquidez concentrada (arquitectura Uniswap v3): rangos de ticks, Q64.96, tick bitmap y swaps multi-tick. Solidity `0.8.24` + Foundry.

**Estado:** Fase **0** ✅ (setup). Fases **1–7** pendientes de autorización.

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

Autorizar **Fase 1** (`FullMath` + `TickMath`).
