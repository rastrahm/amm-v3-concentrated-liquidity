# Flujograma — Ciclo completo AMM v3 Concentrated Liquidity

Flujo extremo a extremo entre actores y contratos (módulo 14, **diseño v1**): factory, mint, swap multi-tick, burn/collect y testing.

## Actores

| Actor | Rol |
|-------|-----|
| Liquidity Provider (LP) | Aporta liquidez en un rango de ticks; cobra fees |
| Trader / Swapper | Intercambia token0 ↔ token1 contra el pool |
| CLFactory | Crea e indexa pools por par + fee |
| CLPool | Custodia tokens, ticks, posiciones y ejecuta swaps |
| TickBitmap / Tick / Position | Estructuras internas de liquidez y fees |
| CI / Foundry | Unit, fuzz, gas, out-of-range |

---

## Flujograma principal — Deploy + createPool

```mermaid
flowchart TD
    Start([Inicio]) --> Dep[Deploy CLFactory]
    Dep --> Fee[enableFeeAmount: fee → tickSpacing]
    Fee --> Create[createPool tokenA, tokenB, fee]
    Create --> Sort{tokenA < tokenB?}
    Sort -->|Ordenar| Pool[Deploy CLPool token0, token1, fee, spacing]
    Sort -->|Ya ordenados| Pool
    Pool --> Init[pool.initialize sqrtPriceX96]
    Init --> Ready([Pool listo — slot0 seteado])
```

---

## Flujograma principal — Provisión de liquidez (mint)

```mermaid
flowchart TD
    Start([LP quiere aportar]) --> Choose[Elige tickLower, tickUpper, L]
    Choose --> Mint[CLPool.mint]
    Mint --> Val{ticks válidos y L > 0?}
    Val -->|No| Err[InvalidTickRange / ZeroLiquidity / TickNotSpaced]
    Val -->|Sí| Upd[Update ticks + bitmap + position]
    Upd --> Amt[Calcular amount0/amount1 según P]
    Amt --> Pay[LP transfiere tokens al pool]
    Pay --> Ok([Posición activa o out-of-range según P])
    Err --> Fail([Fin — rechazo])
```

---

## Flujograma principal — Swap multi-tick

```mermaid
flowchart TD
    Start([Trader inicia swap]) --> Call[CLPool.swap zeroForOne, amount, limit]
    Call --> Loop{¿queda amount y P ≠ limit?}
    Loop -->|No| Settle[Transferir net amounts; emit Swap]
    Loop -->|Sí| Next[Buscar next initialized tick en bitmap]
    Next --> Step[SwapMath: avanzar precio / consumir amount / fee]
    Step --> Cross{¿cruzó tick?}
    Cross -->|Sí| Net[Tick.cross; ajustar L con liquidityNet]
    Cross -->|No| Loop
    Net --> Loop
    Settle --> End([Fin — OK])
```

---

## Flujograma principal — Burn + collect fees

```mermaid
flowchart TD
    Start([LP retira]) --> Burn[CLPool.burn amount en rango]
    Burn --> Fees[Position acumula tokensOwed principal + fees]
    Fees --> Collect[CLPool.collect]
    Collect --> Xfer[SafeERC20 a recipient]
    Xfer --> End([Fin — LP recibe token0/token1])
```

---

## Flujograma — Fees in-range vs out-of-range

```mermaid
flowchart TD
    A[Swap ocurre en tickActual] --> B{¿posición cubre tickActual?}
    B -->|Sí in-range| C[Comparte feeGrowthGlobal vía feeGrowthInside]
    B -->|No out-of-range| D[No incrementa fees de esa posición]
    C --> E[LP collect > 0 fees]
    D --> F[Test: fees owed de swap = 0]
```

---

## Flujograma — Ataques / misuse típicos

```mermaid
flowchart TD
    A[Mint con tickLower >= tickUpper] --> B[InvalidTickRange]
    C[Mint con amount = 0] --> D[ZeroLiquidity]
    E[Swap con sqrtPriceLimit inválido] --> F[PriceTargetExceeded / InvalidSqrtPrice]
    G[Ticks no múltiplo de spacing] --> H[TickNotSpaced]
    I[Esperar fees con posición fuera de P] --> J[0 fees — by design]
```

---

## Secuencia — camino feliz mint + swap + collect

```mermaid
sequenceDiagram
    actor LP as Liquidity Provider
    actor Tr as Trader
    participant Fac as CLFactory
    participant Pool as CLPool
    participant BM as TickBitmap
    participant Pos as Position

    LP->>Fac: createPool(token0, token1, fee)
    Fac-->>LP: pool
    LP->>Pool: initialize(sqrtPriceX96)
    LP->>Pool: mint(LP, tickLower, tickUpper, L)
    Pool->>BM: flipTick (si nuevo)
    Pool->>Pos: update(+L)
    Pool-->>LP: amount0, amount1 (transfer in)

    Tr->>Pool: swap(recipient, zeroForOne, amount, limit)
    Pool->>BM: nextInitializedTickWithinOneWord
    Pool->>Pool: computeSwapStep + feeGrowthGlobal
    Pool-->>Tr: amount0, amount1

    LP->>Pool: burn(tickLower, tickUpper, L)
    Pool->>Pos: update(-L) + tokensOwed
    LP->>Pool: collect(LP, range, max, max)
    Pool-->>LP: token0 + token1 (+ fees)
```

---

## Secuencia — un step de swap que cruza tick

```mermaid
sequenceDiagram
    participant Pool as CLPool
    participant BM as TickBitmap
    participant SM as SwapMath
    participant Tick as Tick
    participant LM as LiquidityMath

    Pool->>BM: nextInitializedTick(tick, lte)
    BM-->>Pool: tickNext, initialized
    Pool->>SM: computeSwapStep(current, target, L, amount, fee)
    SM-->>Pool: sqrtP', amountIn, amountOut, feeAmount
    alt precio alcanza tickNext y está inicializado
        Pool->>Tick: cross(tickNext)
        Tick-->>Pool: liquidityNet
        Pool->>LM: addDelta(L, ±liquidityNet)
        LM-->>Pool: L'
    end
    Pool->>Pool: actualizar slot0.tick / sqrtPriceX96
```

---

## Gobernanza de implementación

```mermaid
flowchart LR
    Doc[doc/ ✅] --> F0[Fase 0 Setup ✅]
    F0 --> F1[Fase 1 FullMath/TickMath ✅]
    F1 --> F2[Fase 2 Sqrt/Liq/SwapMath ✅]
    F2 --> F3[Fase 3 Bitmap/Tick/Position ⏳]
    F3 --> F4[Fase 4 Mint/Burn/Collect]
    F4 --> F5[Fase 5 Swap multi-tick]
    F5 --> F6[Fase 6 Factory/e2e/fuzz]
    F6 --> F7[Fase 7 Gas/Deploy/SWC]
    F7 --> Done([Módulo v1])
```

**Gate:** no avanzar de fase sin *“autorizo Fase N”*. Detalle en [`planificacion.md`](./planificacion.md).  
**Estado:** Fases **0–2** ✅. Siguiente: **Fase 3**.
