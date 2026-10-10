# Flow diagram — Mint, Burn, Swap, and Fees (CL AMM v3)

Internal decision flows of the concentrated liquidity pool (module 14, **v1 design**).

## 1. Mint — provide liquidity in a range

```mermaid
flowchart TD
    A[Caller: mint recipient, tickLower, tickUpper, amount] --> B{amount > 0?}
    B -->|No| Z1[Revert ZeroLiquidity]
    B -->|Yes| C{tickLower < tickUpper and within MIN/MAX?}
    C -->|No| Z2[Revert InvalidTickRange]
    C -->|Yes| D{ticks aligned to tickSpacing?}
    D -->|No| Z3[Revert TickNotSpaced]
    D -->|Yes| E[Update Tick lower/upper + bitmap if needed]
    E --> F[Position.update + liquidity]
    F --> G{price P vs range?}
    G -->|P < Plower| H[token0 only: amount0 = f L, Plower, Pupper]
    G -->|Plower ≤ P < Pupper| I[token0 + token1: active L += amount]
    G -->|P ≥ Pupper| J[token1 only: amount1 = f L, Plower, Pupper]
    H --> K[Transfer tokens to the pool — CEI + SafeERC20]
    I --> K
    J --> K
    K --> L[Emit Mint / return amount0, amount1]
    Z1 --> End([End])
    Z2 --> End
    Z3 --> End
    L --> End
```

> Rounding: amounts computed **UP** (favors the pool).

## 2. Burn — withdraw liquidity

```mermaid
flowchart TD
    A[Caller: burn tickLower, tickUpper, amount] --> B{amount > 0 and position has L?}
    B -->|No| Z[Revert ZeroLiquidity / InvalidTickRange]
    B -->|Yes| C[Position.update: L -= amount; accrue fees owed]
    C --> D[Tick.update lower/upper; flip bitmap if liquidityGross → 0]
    D --> E{P inside the range?}
    E -->|Yes| F[active liquidity -= amount]
    E -->|No| G[Global L unchanged]
    F --> H[Compute amount0/amount1 DOWN]
    G --> H
    H --> I[tokensOwed += amounts; Emit Burn]
    I --> End([End — tokens via collect])
    Z --> End
```

## 3. Collect — claim owed tokens / fees

```mermaid
flowchart TD
    A[collect recipient, range, amount0Req, amount1Req] --> B[Read tokensOwed0/1 from Position]
    B --> C[amountOut = min requested, owed]
    C --> D[Subtract owed; SafeERC20 transfer]
    D --> E[Emit Collect]
    E --> End([End])
```

## 4. Swap — multi-tick loop

```mermaid
flowchart TD
    A[swap: zeroForOne, amountSpecified, sqrtPriceLimitX96] --> B{limit valid vs current price?}
    B -->|No| R1[Revert PriceTargetExceeded / InvalidSqrtPrice]
    B -->|Yes| C[state = slot0; amountRemaining = amountSpecified]
    C --> D{amount remaining and price ≠ limit?}
    D -->|No| M[Persist slot0, liquidity, feeGrowth; transfer]
    D -->|Yes| E[TickBitmap: next initialized tick]
    E --> F[sqrtPriceTarget = min/max nextTick, limit]
    F --> G[SwapMath.computeSwapStep]
    G --> H[Update amountRemaining, feeGrowthGlobal]
    H --> I{reached the initialized tick price?}
    I -->|Yes| J[Tick.cross; L = addDelta L, liquidityNet]
    I -->|No| K[Intermediate price within the step]
    J --> D
    K --> D
    M --> End([End — amount0, amount1])
    R1 --> End
```

## 5. Amount calculation by location of P

```mermaid
flowchart TD
    A[Range Plower, Pupper + liquidity L] --> B{current sqrtP?}
    B -->|sqrtP ≤ sqrtPlower| C["amount0 = L · (1/√Plower − 1/√Pupper)\namount1 = 0"]
    B -->|sqrtPlower < sqrtP < sqrtPupper| D["amount0 = L · (1/√P − 1/√Pupper)\namount1 = L · (√P − √Plower)"]
    B -->|sqrtP ≥ sqrtPupper| E["amount0 = 0\namount1 = L · (√Pupper − √Plower)"]
```

## 6. Fee growth — active vs out-of-range position

```mermaid
flowchart TD
    A[Swap generates fee] --> B[feeGrowthGlobal*X128 += fee / active_L]
    B --> C{position with tickLower ≤ currentTick < tickUpper?}
    C -->|Yes| D[feeGrowthInside increases → Position accrues tokensOwed]
    C -->|No| E[feeGrowthInside of that position does not grow → 0 new fees]
    D --> F[collect can withdraw fees]
    E --> G[Assert tests: out-of-range inactivity]
```

## 7. State cycle — slot0 during a swap

```mermaid
stateDiagram-v2
    [*] --> Locked: swap starts (unlocked = false)

    Locked --> Step: amountRemaining > 0
    Step --> CrossTick: price reaches initialized tick
    Step --> MidPrice: step exhausts amount without crossing
    CrossTick --> UpdateL: liquidityNet applied
    UpdateL --> Step: continue loop
    MidPrice --> Done: amountRemaining = 0 or limit hit
    Step --> Done: price == sqrtPriceLimit

    Done --> Unlocked: persist state (unlocked = true)
    Unlocked --> [*]
```

## 8. Cross-cutting rule — rounding

```mermaid
flowchart LR
    Dep[Deposit / amount in to the pool] --> UP[Round UP — favors pool]
    Ret[Withdrawal / amount out of the pool] --> DOWN[Round DOWN — favors pool]
```

Spanish version: [`diagrama-de-flujo-ES.md`](./diagrama-de-flujo-ES.md)
