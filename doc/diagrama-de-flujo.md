# Diagrama de flujo — Mint, Burn, Swap y Fees (CL AMM v3)

Flujos de decisión internos del pool de liquidez concentrada (módulo 14, **diseño v1**).

## 1. Mint — aportar liquidez en rango

```mermaid
flowchart TD
    A[Caller: mint recipient, tickLower, tickUpper, amount] --> B{¿amount > 0?}
    B -->|No| Z1[Revert ZeroLiquidity]
    B -->|Sí| C{¿tickLower < tickUpper y dentro de MIN/MAX?}
    C -->|No| Z2[Revert InvalidTickRange]
    C -->|Sí| D{¿ticks alineados a tickSpacing?}
    D -->|No| Z3[Revert TickNotSpaced]
    D -->|Sí| E[Actualizar Tick lower/upper + bitmap si procede]
    E --> F[Position.update + liquidity]
    F --> G{¿precio P vs rango?}
    G -->|P < Plower| H[Solo token0: amount0 = f L, Plower, Pupper]
    G -->|Plower ≤ P < Pupper| I[token0 + token1: L activa += amount]
    G -->|P ≥ Pupper| J[Solo token1: amount1 = f L, Plower, Pupper]
    H --> K[Transferir tokens al pool — CEI + SafeERC20]
    I --> K
    J --> K
    K --> L[Emit Mint / retornar amount0, amount1]
    Z1 --> End([Fin])
    Z2 --> End
    Z3 --> End
    L --> End
```

> Redondeo: amounts calculados **UP** (favorece al pool).

## 2. Burn — retirar liquidez

```mermaid
flowchart TD
    A[Caller: burn tickLower, tickUpper, amount] --> B{¿amount > 0 y posición tiene L?}
    B -->|No| Z[Revert ZeroLiquidity / InvalidTickRange]
    B -->|Sí| C[Position.update: L -= amount; acumular fees owed]
    C --> D[Tick.update lower/upper; flip bitmap si liquidityGross → 0]
    D --> E{¿P dentro del rango?}
    E -->|Sí| F[liquidity activa -= amount]
    E -->|No| G[L global sin cambio]
    F --> H[Calcular amount0/amount1 DOWN]
    G --> H
    H --> I[tokensOwed += amounts; Emit Burn]
    I --> End([Fin — tokens vía collect])
    Z --> End
```

## 3. Collect — cobrar tokens / fees owed

```mermaid
flowchart TD
    A[collect recipient, range, amount0Req, amount1Req] --> B[Leer tokensOwed0/1 de Position]
    B --> C[amountOut = min requested, owed]
    C --> D[Restar owed; transfer SafeERC20]
    D --> E[Emit Collect]
    E --> End([Fin])
```

## 4. Swap — bucle multi-tick

```mermaid
flowchart TD
    A[swap: zeroForOne, amountSpecified, sqrtPriceLimitX96] --> B{¿limit válido vs precio actual?}
    B -->|No| R1[Revert PriceTargetExceeded / InvalidSqrtPrice]
    B -->|Sí| C[state = slot0; amountRemaining = amountSpecified]
    C --> D{¿queda amount y precio ≠ limit?}
    D -->|No| M[Persistir slot0, liquidity, feeGrowth; transferir]
    D -->|Sí| E[TickBitmap: next initialized tick]
    E --> F[sqrtPriceTarget = min/max nextTick, limit]
    F --> G[SwapMath.computeSwapStep]
    G --> H[Actualizar amountRemaining, feeGrowthGlobal]
    H --> I{¿alcanzó precio del tick inicializado?}
    I -->|Sí| J[Tick.cross; L = addDelta L, liquidityNet]
    I -->|No| K[Precio intermedio en el step]
    J --> D
    K --> D
    M --> End([Fin — amount0, amount1])
    R1 --> End
```

## 5. Cálculo de amounts según ubicación de P

```mermaid
flowchart TD
    A[Rango Plower, Pupper + liquidez L] --> B{¿sqrtP actual?}
    B -->|sqrtP ≤ sqrtPlower| C["amount0 = L · (1/√Plower − 1/√Pupper)\namount1 = 0"]
    B -->|sqrtPlower < sqrtP < sqrtPupper| D["amount0 = L · (1/√P − 1/√Pupper)\namount1 = L · (√P − √Plower)"]
    B -->|sqrtP ≥ sqrtPupper| E["amount0 = 0\namount1 = L · (√Pupper − √Plower)"]
```

## 6. Fee growth — posición activa vs out-of-range

```mermaid
flowchart TD
    A[Swap genera fee] --> B[feeGrowthGlobal*X128 += fee / L_activa]
    B --> C{¿posición con tickLower ≤ tickActual < tickUpper?}
    C -->|Sí| D[feeGrowthInside aumenta → Position acumula tokensOwed]
    C -->|No| E[feeGrowthInside de esa posición no crece → 0 fees nuevos]
    D --> F[collect puede retirar fees]
    E --> G[Assert tests: out-of-range inactivity]
```

## 7. Ciclo de estados — slot0 durante un swap

```mermaid
stateDiagram-v2
    [*] --> Locked: swap inicia (unlocked = false)

    Locked --> Step: hay amountRemaining
    Step --> CrossTick: precio alcanza tick inicializado
    Step --> MidPrice: step agota amount sin cruzar
    CrossTick --> UpdateL: liquidityNet aplicado
    UpdateL --> Step: continuar bucle
    MidPrice --> Done: amountRemaining = 0 o hit limit
    Step --> Done: precio == sqrtPriceLimit

    Done --> Unlocked: persistir estado (unlocked = true)
    Unlocked --> [*]
```

## 8. Regla transversal — redondeo

```mermaid
flowchart LR
    Dep[Depósito / amount in al pool] --> UP[Round UP — favorece pool]
    Ret[Retiro / amount out del pool] --> DOWN[Round DOWN — favorece pool]
```
