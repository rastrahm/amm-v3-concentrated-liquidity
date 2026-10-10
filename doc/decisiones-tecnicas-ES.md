# Decisiones técnicas, lógica y gas — AMM v3 Concentrated Liquidity

Documento de comprensión del módulo 14 (v1 cerrado). Complementa [`planificacion-ES.md`](./planificacion-ES.md), [`GAS-ES.md`](./GAS-ES.md) y [`diagrama-de-flujo-ES.md`](./diagrama-de-flujo-ES.md).

---

## 1. Qué problema resuelve

Un AMM tipo Uniswap v2 reparte la liquidez en **todo** el rango de precios. Aquí se replica la idea de Uniswap v3: el LP elige un intervalo `[tickLower, tickUpper]` y concentra capital donde espera volumen. El pool cotiza con $\sqrt{P}$ en punto fijo **Q64.96** (`sqrtPriceX96`) y ejecuta swaps **por pasos** (steps), cruzando ticks inicializados y moviendo la liquidez activa $L$.

---

## 2. Decisiones técnicas (por qué se hizo así)

### 2.1 Arquitectura Uniswap v3–style (core, no periphery)

| Decisión | Motivo |
|----------|--------|
| Separar **core** (`CLPool` / `CLFactory`) de periphery | El núcleo es el motor de liquidez; routers NFT/multi-hop quedan fuera de v1. |
| Callbacks `clMintCallback` / `clSwapCallback` | El pool no hace `transferFrom` del usuario: el caller (router) paga en el mismo tx midiendo **delta de balance**. Patrón Uniswap. |
| Sin NFT Position Manager | Las posiciones viven en un mapping por `(owner, tickLower, tickUpper)`. Menos código/gas en core. |
| Sin TWAP / observations | Menos `SSTORE` por swap; oráculo de precio histórico = post-v1. |
| Sin protocol fee | Menos ramas en fee growth; fee 100% a LPs in-range. |
| Flash swaps fuera de alcance | Se reserva el error `FlashSlippage`; no hay path flash en v1. |

### 2.2 Stack y reglas del monorepo

| Decisión | Motivo |
|----------|--------|
| `pragma solidity 0.8.24` fijo | Sin floating pragma (SWC-103); misma versión en `foundry.toml`. |
| Custom errors (`CLErrors`) | Más baratos y tipados que `require("…")`. |
| SafeERC20 (OZ v5) | Tokens no estándar (retornos vacíos) no rompen transfers. |
| Lock en `slot0.unlocked` | Anti-reentrancy Uniswap-style (un slot con precio/tick), no `ReentrancyGuard` separado. |
| Redondeo **UP** en depósitos / **DOWN** en retiros | Favorece al pool; evita drenar el contrato por dust. |
| Fuzz ≥ 1000 runs | Exigencia del suite; ticks MIN/MAX y amounts. |

### 2.3 Matemática y estado

| Decisión | Motivo |
|----------|--------|
| Precio como `sqrtPriceX96` (Q64.96) | Misma representación que Uniswap v3: cantidades se obtienen con diferencias de $\sqrt{P}$ y $1/\sqrt{P}$. |
| `FullMath.mulDiv` (512-bit) | Evita overflow intermedio en fee growth y amounts. |
| `TickBitmap` (`mapping(int16 => uint256)`) | Buscar el próximo tick inicializado en **O(1) por word** (256 ticks). |
| Fee growth global + outside por tick | Las fees se contabilizan sin iterar posiciones; cada posición deriva `feeGrowthInside`. |
| Fee tiers factory: 500/10, 3000/60, 10000/200 | Espaciado de ticks acoplado al fee (como Uniswap v3). |
| Factory con `new CLPool` (no CREATE2 deployer) | Simplicidad v1; dirección no determinística tipo Uniswap Factory+PoolDeployer. |

### 2.4 Seguridad (diseño, no “feature”)

| Decisión | Motivo |
|----------|--------|
| Validar ticks: `lower < upper`, MIN/MAX, `tickSpacing` | Evita rangos basura y bitmap mal alineado. |
| `sqrtPriceLimitX96` en swap | Slippage / dirección; si el límite es inválido → `PriceTargetExceeded`. |
| Pago por balance post-callback | El pool no confía en el callback: exige que el balance haya subido lo pedido. |
| Out-of-range → 0 fees | Solo liquidez **activa** (precio dentro del rango) recibe fee growth del swap. |

---

## 3. Lógica que sigue el sistema

### 3.1 Mapa mental

```
Factory.createPool(tokenA, tokenB, fee)
        │
        ▼
   CLPool (token0 < token1, fee, tickSpacing)
        │
        ├── initialize(sqrtPriceX96)     → slot0 (precio, tick, unlocked)
        ├── mint  → _modifyPosition(+)  → callback pago → check balances
        ├── burn  → _modifyPosition(-)  → tokensOwed += amounts  (burn(0)=poke fees)
        ├── collect → baja tokensOwed → safeTransfer
        └── swap  → bucle steps → transfer out → callback in → check balance
```

### 3.2 Dónde está la liquidez (regla de oro)

Dado un rango `[P_lower, P_upper]` y liquidez $L$:

| Precio actual $P$ | Qué aporta el LP | ¿Cuenta como L activa? |
|-------------------|------------------|-------------------------|
| $P \le P_{lower}$ | Solo token0 | No (aún no entró al rango) |
| $P_{lower} < P < P_{upper}$ | token0 + token1 | **Sí** (`liquidity` global += ΔL) |
| $P \ge P_{upper}$ | Solo token1 | No (ya salió del rango) |

Eso lo calcula `SqrtPriceMath` a partir de `sqrtPriceX96` y $L$.

### 3.3 Mint (aportar)

1. `lock` → evita reentrada.
2. Valida ticks / spacing / `amount > 0`.
3. Actualiza ticks lower/upper (`liquidityGross` / `liquidityNet`) y bitmap si el tick pasa de vacío a usado.
4. Actualiza `Position` (liquidez + fee growth inside).
5. Si el precio está **dentro** del rango, suma ΔL a `liquidity` global.
6. Calcula `amount0` / `amount1` (redondeo UP).
7. Callback al caller → debe transferir tokens al pool.
8. Verifica balances; si faltan → `InsufficientToken0/1`.

### 3.4 Burn + collect (retirar)

1. Burn **no** envía tokens al usuario: acumula en `tokensOwed*`.
2. `burn(0)` = **poke**: solo sincroniza fees acumuladas a `tokensOwed` sin mover L.
3. `collect` resta de `tokensOwed` y hace `safeTransfer` (CEI: primero deuda, luego transfer).

### 3.5 Swap (bucle multi-tick)

1. Valida `amountSpecified ≠ 0` y `sqrtPriceLimitX96` respecto a dirección y bounds.
2. Mientras quede amount y el precio no haya tocado el límite:
   - Busca el **próximo tick inicializado** en el bitmap.
   - Calcula el target del step (tick siguiente vs límite de precio).
   - `SwapMath.computeSwapStep` → Δprecio, amountIn, amountOut, fee.
   - Actualiza fee growth global (`fee / L` si $L > 0$).
   - Si el step **llega** al tick: `Tick.cross` y aplica `liquidityNet` a $L$ activa.
3. Persiste `slot0`, `liquidity`, `feeGrowthGlobal*`.
4. Transfiere el token de salida al `recipient`.
5. Callback pide el token de entrada; verifica balance.

Exact input: `amountSpecified > 0`. Exact output: `amountSpecified < 0` (mismo bucle, signos invertidos en el estado).

### 3.6 Fees

- Cada swap incrementa `feeGrowthGlobal0X128` o `feeGrowthGlobal1X128`.
- Al cruzar un tick se guarda `feeGrowthOutside`.
- Una posición solo “ve” el growth **inside** su rango.
- Si el precio nunca estuvo (o no está) en su rango durante el swap, **no** gana fees → validado en `OutOfRangeFees.t.sol`.

---

## 4. ¿Se puede mejorar el gas de lo que existe?

Sí. El v1 ya aplica immutables, libraries, custom errors, bitmap y `via_ir`. Abajo: mejoras **realistas** sobre este código, ordenadas por impacto / riesgo.

### 4.1 Ya aplicado (baseline)

Ver números en [`GAS-ES.md`](./GAS-ES.md) (tests con router; no son gas “puro” del pool).

| Técnica | Efecto |
|---------|--------|
| Config del pool `immutable` | Evita SLOAD en hot path |
| Math en libraries + `via_ir` + `optimizer_runs=10_000` | Inlining agresivo |
| Custom errors | Reverts baratos |
| Tick bitmap | Menos búsqueda lineal de ticks |
| Lock embebido en `slot0` | Un storage slot vs guard separado |
| Sin TWAP / protocol fee / NFT | Menos writes por swap |

### 4.2 Mejoras posibles (v2 / hardening)

| Idea | Impacto estimado | Riesgo / nota |
|------|------------------|---------------|
| **Packing adicional de `Tick.Info` / `Position.Info`** | Medio en mint/burn/cross | Hay que respetar layout Uniswap-like; fuzz intensivo. |
| **Cachear `slot0` / `liquidity` en memoria** más agresivo en swap | Bajo–medio | Ya se usa `SwapState` en memoria; revisar SLOADs residuales. |
| **Transient storage (Cancun) para el lock** | Bajo en reentrancy path | `slot0.unlocked` seguiría siendo patrón Uniswap; transient es alternativa moderna. |
| **Assembler hot paths** (`SwapMath` / `SqrtPriceMath`) | Medio–alto | Complejidad y auditoría; Uniswap ya usa assembly selectivo. |
| **Exact input-only API** (eliminar ramas exact output) | Bajo–medio en bytecode/swap | Reduce superficie; pierdes exact-out nativo. |
| **Router periphery gas-aware** (batch mint+collect, multicall) | Alto *para el usuario* | No baja gas del pool; baja nº de txs / calldata. |
| **CREATE2 + PoolDeployer** | Deploy, no runtime | Direcciones predictibles; no acelera swap. |
| **Protocol fee off / storage sparse** | Ya off | Mantener off en v1 es correcto para gas. |
| **Medir gas “puro”** (`vm.snapshotGas` / call directo sin router) | Claridad | Los números actuales incluyen hop del helper; no confundir con Uniswap published gas. |

### 4.3 Lo que **no** conviene “optimizar” a ciegas

| Tentación | Por qué no |
|-----------|------------|
| Quitar el lock | Reentrancy vía callback = robo / estado inconsistente. |
| Redondear DOWN en mint | Drena el pool a favor del LP (adversarial). |
| Saltar verificación de balance post-callback | Confiarías en un router malicioso. |
| Iterar posiciones en cada swap | Peor gas y no escala. |
| Subir `optimizer_runs` sin medir | Puede **empeorar** runtime si se optimiza para deploy. |

### 4.4 Lectura práctica

1. El coste dominante de un **swap largo** no es una micro-optimización: es **cuántos ticks cruzas**. Menos liquidez fragmentada en ticks = menos gas.
2. El coste dominante de **mint** es escribir ticks + posición + callback ERC-20.
3. Mejoras de gas “de producto” (router, batching) suelen dar más UX que pelear 200 gas en `mulDiv`.

---

## 5. Flujo resumido (una frase por operación)

| Operación | En una frase |
|-----------|----------------|
| `createPool` | Ordena tokens, mira fee tier, despliega `CLPool`. |
| `initialize` | Fija el primer `sqrtPriceX96` / tick; abre el lock. |
| `mint` | Suma L al rango, cobra tokens vía callback. |
| `burn` | Resta L, acredita tokens/fees en `tokensOwed`. |
| `collect` | Paga al usuario desde `tokensOwed`. |
| `swap` | Mueve el precio por steps, reparte fees a L activa, cobra/paga vía transfer+callback. |

---

## 6. Referencias internas

| Doc | Contenido |
|-----|-----------|
| [`planificacion-ES.md`](./planificacion-ES.md) | Fases 0–7, alcance, criterios |
| [`diagrama-de-clases-ES.md`](./diagrama-de-clases-ES.md) | Contratos y libs |
| [`diagrama-de-flujo-ES.md`](./diagrama-de-flujo-ES.md) | Mermaid mint/burn/swap/fees |
| [`flujograma-ES.md`](./flujograma-ES.md) | Actor–sistema e2e |
| [`GAS-ES.md`](./GAS-ES.md) | Snapshot y tradeoffs |
| [`SWC-AUDIT-ES.md`](./SWC-AUDIT-ES.md) | Matriz SWC-100–136 |

Código: `src/CLPool.sol`, `src/CLFactory.sol`, `src/libraries/*`.

English version: [`decisiones-tecnicas-EN.md`](./decisiones-tecnicas-EN.md)
