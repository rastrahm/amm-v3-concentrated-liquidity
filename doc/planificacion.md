# Planificación — Módulo 14: AMM v3 Concentrated Liquidity & Tick Math

**Estado:** Fases **0–4** ✅ completadas. Fases **5–7** pendientes de autorización.  
**Regla de avance:** cada fase requiere **autorización explícita** del responsable antes de empezar (*“autorizo Fase N”* o equivalente).

---

## 1. Objetivo

Construir un motor de **AMM con liquidez concentrada** (arquitectura Uniswap v3) que soporte:

- Provisión de liquidez en rangos `[tickLower, tickUpper]` con cálculo exacto de `token0` / `token1` según la posición del precio actual.
- Matemática de punto fijo **Q64.96** (`sqrtPriceX96`) vía `FullMath` / `TickMath`.
- **Tick bitmap** (`mapping(int16 => uint256)`) para búsqueda $O(1)$ del siguiente tick inicializado.
- Swaps **paso a paso** cruzando ticks, actualizando `feeGrowthGlobal*X128` y la liquidez activa $L$.
- Stack: **Foundry + Solidity `0.8.24`** (pragma fijo).

---

## 2. Alcance

| Incluido (v1) | Excluido (v1) |
|---------------|---------------|
| Pool concentrado: mint / burn / swap / collect fees | Oracles TWAP / observations (post-v1) |
| Libs: `FullMath`, `TickMath`, `SqrtPriceMath`, `LiquidityMath`, `SwapMath`, `TickBitmap`, `Tick`, `Position` | NFT Position Manager (ERC-721) |
| Factory de pools por `(token0, token1, fee)` | Router multi-hop / periphery compleja |
| Fee growth global + fees por posición en rango activo | Flash swaps completos (solo error `FlashSlippage` si se stubbea) |
| Tests: single-range, multi-tick swap, out-of-range = 0 fees, fuzz MIN/MAX tick | Frontend Next.js |
| Custom errors del módulo + CEI + NatSpec | Governance on-chain de fees |

---

## 3. Stack y restricciones técnicas

### Suite (`evm-smart-contracts-suite`)

- Solidity **exacto** `0.8.24` (sin floating pragma).
- OpenZeppelin Contracts v5.x (SafeERC20, ReentrancyGuard donde aplique).
- Foundry: unit + fuzz (`runs >= 1000`) + gas reports.
- Custom errors (no `require` con strings).
- CEI estricto; transferencias ERC-20 vía SafeERC20; ETH vía `.call{value}` si aplica.
- NatSpec en toda API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.
- Redondeo: **UP** en depósitos (favorece al pool); **DOWN** en retiros.

### Módulo 14 (Concentrated Liquidity)

- Precio interno: $\sqrt{P}$ en **Q64.96** (`uint160 sqrtPriceX96`).
- Ticks: `MIN_TICK` / `MAX_TICK` alineados a spacing del fee tier.
- Bitmap: `mapping(int16 => uint256) public tickBitmap`.
- Swap: bucle de steps hasta agotar `amountSpecified` o alcanzar `sqrtPriceLimitX96`.
- Posiciones fuera del rango activo: **cero fees** de swap.

---

## 4. Arquitectura (propuesta v1)

```
14-amm-v3-concentrated-liquidity/
├── README.md
├── doc/
│   ├── README.md
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   └── flujograma.md
├── src/
│   ├── CLPool.sol                    # Pool core: mint / burn / swap / collect
│   ├── CLFactory.sol                 # Crea pools por token0/token1/fee
│   ├── interfaces/
│   │   ├── ICLPool.sol
│   │   └── ICLFactory.sol
│   ├── libraries/
│   │   ├── FullMath.sol              # mulDiv 512-bit
│   │   ├── TickMath.sol              # tick ↔ sqrtPriceX96
│   │   ├── SqrtPriceMath.sol         # Δtoken0/1 dado L y precios
│   │   ├── LiquidityMath.sol         # addDelta(L, ΔL)
│   │   ├── SwapMath.sol              # un step de swap
│   │   ├── TickBitmap.sol            # nextInitializedTickWithinOneWord
│   │   ├── Tick.sol                  # update / cross tick
│   │   └── Position.sol              # update posición + fees owed
│   ├── errors/
│   │   └── CLErrors.sol
│   └── mocks/
│       └── MockERC20.sol
├── test/
│   ├── helpers/CLTestBase.sol
│   ├── libraries/                    # unit por lib
│   ├── CLPool.mint.t.sol
│   ├── CLPool.burn.t.sol
│   ├── CLPool.swap.t.sol
│   ├── CLPool.fees.t.sol
│   ├── OutOfRangeFees.t.sol
│   ├── fuzz/TickMath.fuzz.t.sol
│   ├── fuzz/CLPool.fuzz.t.sol
│   └── gas/CLPool.gas.t.sol
├── script/
│   └── Deploy.s.sol
├── foundry.toml
├── remappings.txt
├── .env.example
└── .gas-snapshot
```

### Contratos y responsabilidades

| Artefacto | Responsabilidad |
|-----------|-----------------|
| `FullMath` | `mulDiv` / `mulDivRoundingUp` sin overflow intermedio |
| `TickMath` | `getSqrtRatioAtTick` / `getTickAtSqrtRatio`; `MIN_TICK` / `MAX_TICK` |
| `SqrtPriceMath` | Cantidades `token0`/`token1` entre dos $\sqrt{P}$ dado $L$ |
| `LiquidityMath` | Suma/resta segura de liquidez activa |
| `SwapMath` | Computa un step: precio destino, amounts in/out, fee |
| `TickBitmap` | Flip bit + next initialized tick en word |
| `Tick` | `liquidityGross` / `liquidityNet` / `feeGrowthOutside`; `cross()` |
| `Position` | Key `(owner, tickLower, tickUpper)`; fees owed |
| `CLPool` | Estado global, mint/burn/swap/collect |
| `CLFactory` | Deploy determinístico de pools |
| `CLErrors` | Custom errors del módulo |
| `MockERC20` | Tokens de prueba |

---

## 5. Errores custom (módulo)

```solidity
error InvalidTickRange();
error ZeroLiquidity();
error PriceTargetExceeded();
error FlashSlippage();
```

Errores adicionales esperados en implementación (documentar al autorizar la fase):

```solidity
error ZeroAddress();
error InvalidFee();
error InvalidSqrtPrice();
error InsufficientInputAmount();
error TickNotSpaced();
```

---

## 6. Gobernanza de fases (autorización obligatoria)

| Regla | Detalle |
|-------|---------|
| **Gate** | No se escribe código de una fase hasta: *“autorizo Fase N”*. |
| **Entrega** | Al cerrar: checklist de aceptación + archivos tocados. |
| **Bloqueo** | Alcance nuevo → documentar y esperar nueva autorización. |
| **TDD** | En fases de contratos: tests primero, luego implementación. |

### Tablero de fases

| Fase | Nombre | Estado | Autorización |
|------|--------|--------|--------------|
| 0 | Setup Foundry + estructura + deps | ✅ Completada | ✅ Autorizada |
| 1 | Math core: `FullMath` + `TickMath` | ✅ Completada | ✅ Autorizada |
| 2 | `SqrtPriceMath` + `LiquidityMath` + `SwapMath` | ✅ Completada | ✅ Autorizada |
| 3 | `TickBitmap` + `Tick` + `Position` | ✅ Completada | ✅ Autorizada |
| 4 | `CLPool` mint / burn / collect (sin swap multi-tick) | ✅ Completada | ✅ Autorizada |
| 5 | `CLPool` swap multi-tick + fee growth | ⏳ Pendiente | ❌ No autorizada |
| 6 | `CLFactory` + suite e2e / out-of-range / fuzz | ⏳ Pendiente | ❌ No autorizada |
| 7 | Gas + Deploy + NatSpec / SWC hardening | ⏳ Pendiente | ❌ No autorizada |

> **Próximo paso:** autorizar **Fase 5** (swap multi-tick + fee growth).

---

## 7. Detalle por fase

### Fase 0 — Setup Foundry ✅

**Objetivo:** repo compilable con tooling de la suite.

1. Scaffold Foundry (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`).
2. Dependencias: `forge-std`, OpenZeppelin v5.
3. Carpetas `src/{interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas}`, `script/`, `doc/`.
4. Stub mínimo + smoke test; `.env.example`.

**Criterio de salida:** `forge build` y `forge test` en verde.

**Hecho (2026-09-11):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir`, fuzz `runs = 1000`, `[rpc_endpoints].mainnet`).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencias en `lib/` (gitignored, `--no-git --shallow`): `forge-std`, OpenZeppelin **v5.2.0**.
- Carpetas `src/{interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas,libraries}`, `script/`.
- Stub `src/Placeholder.sol` + `test/Placeholder.t.sol` (ping + remapping IERC20).
- Stub `script/Deploy.s.sol` (Fase 7), `.env.example`, `README.md`.
- `forge build` OK; `forge test` → **3 PASS**.
- Nota: usar `~/.foundry/bin/forge` (el `forge` de nvm/npm no es Foundry).

---

### Fase 1 — FullMath + TickMath ✅

**Objetivo:** base matemática Q64.96 y conversión tick ↔ $\sqrt{P}$.

1. Tests primero: `mulDiv`, rounding up/down, edges de overflow.
2. `TickMath`: `getSqrtRatioAtTick` / `getTickAtSqrtRatio` en `MIN_TICK` / `MAX_TICK` y ticks medios.
3. Fuzz de ida-vuelta tick → sqrt → tick (sin pérdida de precisión fuera de documentación Uniswap).

**Criterio de salida:** libs en verde; fuzz de límites de tick OK.

**Hecho (2026-09-11):**
- `src/errors/CLErrors.sol`: errores del modulo + `DenominatorZero`, `FullMathOverflow`, `InvalidTick`, `InvalidSqrtPrice`.
- `src/libraries/FullMath.sol`: `mulDiv` / `mulDivRoundingUp` (512-bit, Remco Bloemen / Uniswap v3 0.8).
- `src/libraries/TickMath.sol`: `MIN/MAX_TICK`, `MIN/MAX_SQRT_RATIO`, `getSqrtRatioAtTick`, `getTickAtSqrtRatio`.
- Tests: `test/libraries/FullMath.t.sol`, `test/libraries/TickMath.t.sol`, `test/fuzz/TickMath.fuzz.t.sol`.
- Stub `Placeholder` eliminado.
- **`forge test` → 25 PASS** (incl. fuzz 1000 runs).

---

### Fase 2 — SqrtPriceMath + LiquidityMath + SwapMath ✅

**Objetivo:** cantidades de tokens y un step de swap.

1. Tests: amounts cuando $P$ está below / inside / above el rango.
2. Redondeo UP en inputs al pool; DOWN en outputs.
3. `SwapMath.computeSwapStep` con target price y fee.

**Criterio de salida:** fórmulas de liquidez concentrada verificadas vs casos conocidos.

**Hecho (2026-09-11):**
- Auxiliares: `FixedPoint96`, `UnsafeMath`, `SafeCast`.
- `LiquidityMath.addDelta` con `LiquidityOverflow` / `LiquidityUnderflow`.
- `SqrtPriceMath`: `getAmount0/1Delta`, `getNextSqrtPriceFromInput/Output` (custom errors).
- `SwapMath.computeSwapStep` (exact in/out, fee pips).
- Errores nuevos en `CLErrors`: `LiquidityUnderflow/Overflow`, `SafeCastOverflow`, `ZeroSqrtPriceOrLiquidity`.
- Tests: vectores RareSkills (499851), Uniswap next-from-output, rounding UP≥DOWN, swap step.
- **`forge test` → 49 PASS**.

---

### Fase 3 — TickBitmap + Tick + Position ✅

**Objetivo:** estructuras de ticks y posiciones.

1. Bitmap: flip, next initialized (lte / lte).
2. `Tick.update` / `Tick.cross` con `liquidityNet` y `feeGrowthOutside`.
3. `Position.update` con fees owed según fee growth inside.

**Criterio de salida:** lookups O(1) y actualización de fees por tick correctas en unit tests.

**Hecho (2026-09-11):**
- Auxiliares: `BitMath`, `FixedPoint128`.
- `TickBitmap`: `flipTick`, `nextInitializedTickWithinOneWord` (`TickNotSpaced`).
- `Tick` (v1 sin TWAP): `Info`, `update`, `cross`, `getFeeGrowthInside`, `clear`, `tickSpacingToMaxLiquidityPerTick`.
- `Position`: `get` por `(owner, lower, upper)`, `update` con fees owed (`NoLiquidityPosition`).
- Errores: `LiquidityGrossOverflow`, `NoLiquidityPosition`, `BitMathZero`.
- Tests con harnesses de storage: bitmap lte/gt, feeGrowthInside, position fees.
- **`forge test` → 74 PASS**.

---

### Fase 4 — CLPool mint / burn / collect ✅

**Objetivo:** provisión y retiro de liquidez en rango (precio fijo / sin cruzar ticks en swap).

1. Tests TDD: mint single-range; burn; collect; `InvalidTickRange`; `ZeroLiquidity`.
2. Calcular `amount0` / `amount1` según ubicación de $P$.
3. Actualizar ticks + bitmap + posición; transferir tokens (CEI + SafeERC20).

**Criterio de salida:** depósitos/retiros single-range en verde; redondeo a favor del pool.

**Hecho (2026-09-11):**
- `ICLPool`, `ICLMintCallback`, `MockERC20`, `CLPool` (initialize / mint / burn / collect + lock).
- Mint via callback `clMintCallback`; pago verificado por balance.
- Amounts below / inside / above rango; L global solo si P inside.
- Burn acredita `tokensOwed`; collect con SafeERC20.
- Errores: `AlreadyInitialized`, `Locked`, `InsufficientToken0/1`, `InvalidTokenOrder`.
- Tests: `test/CLPool.mint.t.sol` + `test/helpers/CLMintRouter.sol`.
- **`forge test` → 86 PASS**.

---

### Fase 5 — Swap multi-tick + fee growth

**Objetivo:** motor de swap iterativo.

1. Tests: swap dentro de un tick; swap que cruza N ticks; `sqrtPriceLimit`; `PriceTargetExceeded`.
2. Bucle de steps: actualizar precio, L, `feeGrowthGlobal0X128` / `1X128`.
3. Al cruzar tick: `Tick.cross` y ajustar L con `liquidityNet`.

**Criterio de salida:** multi-tick swaps + accrual de fees en rango activo.

---

### Fase 6 — Factory + e2e / out-of-range / fuzz

**Objetivo:** requisitos de testing del `.cursorrules` del módulo.

| Tipo | Qué valida |
|------|------------|
| Unit e2e | mint → swap → burn → collect |
| Out-of-range | posición fuera del tick activo → **0 fees** |
| Fuzz | `MIN_TICK` / `MAX_TICK`, amounts, fee tiers |
| Factory | createPool unique; getPool |

**Criterio de salida:** `forge test` verde; fuzz ≥ 1000; out-of-range inactivity assertado.

---

### Fase 7 — Gas + Deploy + hardening

1. `script/Deploy.s.sol` (factory + pool demo + mocks).
2. `test/gas/CLPool.gas.t.sol` + `.gas-snapshot`.
3. NatSpec completo; `doc/SWC-AUDIT.md` y `doc/GAS.md`.

**Criterio de salida:** deploy local reproducible + docs de seguridad/gas.

---

## 8. Matriz de pruebas (objetivo v1)

| Caso | Qué valida | Fase |
|------|------------|------|
| Mint single-range | amounts correctos below/inside/above | 4 |
| Burn + collect | retiros DOWN; fees owed | 4–5 |
| Swap 1 tick | precio y fees globales | 5 |
| Swap multi-tick | L cambia al cruzar; amounts | 5 |
| Out-of-range fees | fees = 0 fuera del rango | 6 |
| InvalidTickRange / ZeroLiquidity | custom errors | 4 |
| PriceTargetExceeded | límite de precio en swap | 5 |
| Fuzz MIN/MAX tick | precisión Q64.96 | 1, 6 |
| Gas profiling | mint/swap/burn documentados | 7 |

---

## 9. Seguridad (checklist vivo)

- [x] CEI en mint / burn / swap / collect.
- [x] SafeERC20; sin `transfer`/`send` de ETH crudo.
- [x] Custom errors del módulo.
- [x] Redondeo UP depósitos / DOWN retiros.
- [x] Ticks validados: lower < upper, spacing, límites.
- [ ] `sqrtPriceLimitX96` respetado (`PriceTargetExceeded` si aplica).
- [ ] Posiciones out-of-range no acumulan fees de swaps.
- [x] Sin floating pragma; NatSpec en APIs públicas.
- [x] Fuzz de límites de tick.
- [ ] (Fase 7) SWC-AUDIT + gas.

---

## 10. Entregables de documentación (`doc/`)

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| `README.md` | Índice | ✅ |
| `planificacion.md` | Este documento | ✅ |
| `diagrama-de-clases.md` | Estructura y relaciones | ✅ |
| `diagrama-de-flujo.md` | Flujos de decisión | ✅ |
| `flujograma.md` | Flujos actor–sistema e2e | ✅ |
| `SWC-AUDIT.md` | Matriz SWC (Fase 7) | ⏳ |
| `GAS.md` | Benchmarks (Fase 7) | ⏳ |

---

## 11. Criterios de aceptación del módulo

1. [x] Compila con `pragma solidity 0.8.24`.
2. [x] Mint/burn con math de rango (below/inside/above).
3. [ ] Swap multi-tick con actualización de L y fee growth.
4. [x] Tick bitmap con next-initialized O(1) por word.
5. [ ] Out-of-range → zero swap fees.
6. [x] Fuzz MIN/MAX tick + precisión Q64.96.
7. [x] Custom errors + NatSpec.
8. [ ] `doc/SWC-AUDIT.md` sin vulnerabilidades en alcance v1.

---

## 12. Próximo paso

**Esperando autorización de Fase 5** (swap multi-tick + fee growth).

**Nota:** usa `~/.foundry/bin/forge` (o antepón `$HOME/.foundry/bin` al `PATH`); el `forge` de nvm/npm no es Foundry.
