# End-to-end flowchart — AMM v3 Concentrated Liquidity full cycle

End-to-end flow between actors and contracts (module 14, **v1 design**): factory, mint, multi-tick swap, burn/collect, and testing.

## Actors

| Actor | Role |
|-------|------|
| Liquidity Provider (LP) | Provides liquidity in a tick range; collects fees |
| Trader / Swapper | Swaps token0 ↔ token1 against the pool |
| CLFactory | Creates and indexes pools by pair + fee |
| CLPool | Holds tokens, ticks, positions, and executes swaps |
| TickBitmap / Tick / Position | Internal liquidity and fee structures |
| CI / Foundry | Unit, fuzz, gas, out-of-range |

---

## Main flowchart — Deploy + createPool

```mermaid
flowchart TD
    Start([Start]) --> Dep[Deploy CLFactory]
    Dep --> Fee[enableFeeAmount: fee → tickSpacing]
    Fee --> Create[createPool tokenA, tokenB, fee]
    Create --> Sort{tokenA < tokenB?}
    Sort -->|Sort| Pool[Deploy CLPool token0, token1, fee, spacing]
    Sort -->|Already sorted| Pool
    Pool --> Init[pool.initialize sqrtPriceX96]
    Init --> Ready([Pool ready — slot0 set])
```

---

## Main flowchart — Liquidity provision (mint)

```mermaid
flowchart TD
    Start([LP wants to provide]) --> Choose[Chooses tickLower, tickUpper, L]
    Choose --> Mint[CLPool.mint]
    Mint --> Val{valid ticks and L > 0?}
    Val -->|No| Err[InvalidTickRange / ZeroLiquidity / TickNotSpaced]
    Val -->|Yes| Upd[Update ticks + bitmap + position]
    Upd --> Amt[Compute amount0/amount1 based on P]
    Amt --> Pay[LP transfers tokens to the pool]
    Pay --> Ok([Position active or out-of-range depending on P])
    Err --> Fail([End — rejected])
```

---

## Main flowchart — Multi-tick swap

```mermaid
flowchart TD
    Start([Trader starts swap]) --> Call[CLPool.swap zeroForOne, amount, limit]
    Call --> Loop{amount remaining and P ≠ limit?}
    Loop -->|No| Settle[Transfer net amounts; emit Swap]
    Loop -->|Yes| Next[Find next initialized tick in bitmap]
    Next --> Step[SwapMath: advance price / consume amount / fee]
    Step --> Cross{crossed tick?}
    Cross -->|Yes| Net[Tick.cross; adjust L with liquidityNet]
    Cross -->|No| Loop
    Net --> Loop
    Settle --> End([End — OK])
```

---

## Main flowchart — Burn + collect fees

```mermaid
flowchart TD
    Start([LP withdraws]) --> Burn[CLPool.burn amount in range]
    Burn --> Fees[Position accrues tokensOwed principal + fees]
    Fees --> Collect[CLPool.collect]
    Collect --> Xfer[SafeERC20 to recipient]
    Xfer --> End([End — LP receives token0/token1])
```

---

## Flowchart — In-range vs out-of-range fees

```mermaid
flowchart TD
    A[Swap occurs at currentTick] --> B{position covers currentTick?}
    B -->|Yes in-range| C[Shares feeGrowthGlobal via feeGrowthInside]
    B -->|No out-of-range| D[Does not increase fees for that position]
    C --> E[LP collect > 0 fees]
    D --> F[Test: swap fees owed = 0]
```

---

## Flowchart — Typical attacks / misuse

```mermaid
flowchart TD
    A[Mint with tickLower >= tickUpper] --> B[InvalidTickRange]
    C[Mint with amount = 0] --> D[ZeroLiquidity]
    E[Swap with invalid sqrtPriceLimit] --> F[PriceTargetExceeded / InvalidSqrtPrice]
    G[Ticks not a multiple of spacing] --> H[TickNotSpaced]
    I[Expect fees with position outside P] --> J[0 fees — by design]
```

---

## Sequence — happy path mint + swap + collect

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
    Pool->>BM: flipTick (if new)
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

## Sequence — a swap step that crosses a tick

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
    alt price reaches tickNext and it is initialized
        Pool->>Tick: cross(tickNext)
        Tick-->>Pool: liquidityNet
        Pool->>LM: addDelta(L, ±liquidityNet)
        LM-->>Pool: L'
    end
    Pool->>Pool: update slot0.tick / sqrtPriceX96
```

---

## Implementation governance

```mermaid
flowchart LR
    Doc[doc/ ✅] --> F0[Phase 0 Setup ✅]
    F0 --> F1[Phase 1 FullMath/TickMath ✅]
    F1 --> F2[Phase 2 Sqrt/Liq/SwapMath ✅]
    F2 --> F3[Phase 3 Bitmap/Tick/Position ✅]
    F3 --> F4[Phase 4 Mint/Burn/Collect ✅]
    F4 --> F5[Phase 5 Multi-tick swap ✅]
    F5 --> F6[Phase 6 Factory/e2e/fuzz ✅]
    F6 --> F7[Phase 7 Gas/Deploy/SWC ✅]
    F7 --> Done([v1 module closed ✅])
```

**Gate:** do not move to the next phase without *“I authorize Phase N”*. Details in [`planificacion-EN.md`](./planificacion-EN.md).  
**Status:** Phases **0–7** ✅ (v1 module closed).

Spanish version: [`flujograma-ES.md`](./flujograma-ES.md)
