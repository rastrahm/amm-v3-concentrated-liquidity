# Optimización de gas — AMM v3 Concentrated Liquidity

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract CLPoolGasTest --gas-report
forge snapshot --match-contract CLPoolGasTest
```

**Fecha baseline:** 2026-09-11 (Fase 7)  
**Snapshot:** `.gas-snapshot` (`test/gas/CLPool.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`

---

## Baseline operaciones del pool

Medición = gas del **test Foundry** (incluye hop del router de test + callback). Órdenes de magnitud para comparar paths, no coste exacto de solo el `SSTORE` interno del pool.

| Path | Gas (snapshot) | Notas |
|------|----------------|-------|
| `testGas_mint_inRange` | **150 355** | Mint adicional in-range (posición ya existía en setUp) |
| `testGas_swap_exactIn_oneForZero` | **101 435** | Exact input 1→0 |
| `testGas_collect` | **122 570** | Cobro de `tokensOwed` post-poke |
| `testGas_burn` | **105 080** | Burn parcial de liquidez |
| `testGas_burn_poke` | **82 163** | `burn(0)` = actualizar fees owed |
| `testGas_swap_exactIn_zeroForOne` | **77 198** | Exact input 0→1 (post prep swap en setUp) |

### Lectura

- **Mint** es el path más caro del baseline (ticks/posición + callback de pago).
- **Swap** varía con dirección y distancia al límite; el zeroForOne del snapshot es más barato tras el prep del setUp (menos trabajo de inicialización).
- **Poke** (`burn` con amount 0) evita mover liquidez y solo sincroniza fee growth → más barato que burn real.
- **Collect** incluye dos `safeTransfer` ERC-20 cuando hay owed en ambos tokens.

---

## Optimizaciones ya aplicadas en el módulo

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| `factory` / `token0` / `token1` / `fee` / `tickSpacing` / `maxLiquidityPerTick` **immutable** | `CLPool` | Sin SLOAD de config en hot path |
| Math en **libraries** | `SwapMath`, `SqrtPriceMath`, … | Inlining con optimizer / `via_ir` |
| Custom errors | `CLErrors` | Más barato que `require` strings |
| Tick bitmap word lookup | `TickBitmap` | Next-initialized O(1) por word |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Inlining agresivo |
| Lock en `slot0.unlocked` | Uniswap-style | Un slot compartido con precio/tick |

---

## Tradeoffs aceptados

| Decisión | Por qué |
|----------|---------|
| Sin NFT Position Manager | Menos gas/código en core; periphery fuera de v1 |
| Sin TWAP / observations | Menos SSTORE por swap; oracle post-v1 |
| Sin protocol fee | Menos ramas en swap/fee growth |
| Callbacks mint/swap | Patrón Uniswap; caller aporta tokens en el mismo tx |
| Flash swaps fuera de v1 | Menos superficie; error `FlashSlippage` reservado |

---

## Deploy

```bash
# Local (factory + MockERC20 + pool inicializado)
anvil   # otra terminal
export PATH="$HOME/.foundry/bin:$PATH"
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env opcionales: `PRIVATE_KEY`, `FEE` (default 3000), `INIT_TICK` (default 0). Ver `script/Deploy.s.sol` y `.env.example`.

README: [`../README.md`](../README.md) · Índice docs: [`README.md`](./README.md)
