# Class diagram — AMM v3 Concentrated Liquidity

Structural view of contracts, libraries, and interfaces (module 14, **v1 design**).

## Diagram (Mermaid)

```mermaid
classDiagram
    direction TB

    class ICLFactory {
        <<interface>>
        +createPool(tokenA, tokenB, fee) address
        +getPool(token0, token1, fee) address
        +enableFeeAmount(fee, tickSpacing)
    }

    class ICLPool {
        <<interface>>
        +factory() address
        +token0() address
        +token1() address
        +fee() uint24
        +tickSpacing() int24
        +liquidity() uint128
        +slot0() Slot0
        +mint(recipient, tickLower, tickUpper, amount, data) amount0, amount1
        +burn(tickLower, tickUpper, amount) amount0, amount1
        +collect(recipient, tickLower, tickUpper, amount0Req, amount1Req) amount0, amount1
        +swap(recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data) amount0, amount1
    }

    class CLErrors {
        <<errors>>
        +InvalidTickRange()
        +ZeroLiquidity()
        +PriceTargetExceeded()
        +FlashSlippage()
        +ZeroAddress()
        +InvalidFee()
        +InvalidSqrtPrice()
        +TickNotSpaced()
    }

    class FullMath {
        <<library>>
        +mulDiv(a, b, denominator) uint256
        +mulDivRoundingUp(a, b, denominator) uint256
    }

    class TickMath {
        <<library>>
        +MIN_TICK$ int24
        +MAX_TICK$ int24
        +MIN_SQRT_RATIO$ uint160
        +MAX_SQRT_RATIO$ uint160
        +getSqrtRatioAtTick(tick) uint160
        +getTickAtSqrtRatio(sqrtPriceX96) int24
    }

    class SqrtPriceMath {
        <<library>>
        +getAmount0Delta(sqrtA, sqrtB, liquidity, roundUp) uint256
        +getAmount1Delta(sqrtA, sqrtB, liquidity, roundUp) uint256
        +getNextSqrtPriceFromInput(...) uint160
        +getNextSqrtPriceFromOutput(...) uint160
    }

    class LiquidityMath {
        <<library>>
        +addDelta(x, y) uint128
    }

    class SwapMath {
        <<library>>
        +computeSwapStep(sqrtRatioCurrent, sqrtRatioTarget, liquidity, amountRemaining, feePips) StepComputations
    }

    class TickBitmap {
        <<library>>
        +flipTick(self, tick, tickSpacing)
        +nextInitializedTickWithinOneWord(self, tick, tickSpacing, lte) int24, bool
    }

    class Tick {
        <<library>>
        +update(self, tick, tickCurrent, liquidityDelta, ...) bool
        +cross(self, tick, feeGrowthGlobal0, feeGrowthGlobal1) int128
        +getFeeGrowthInside(...) uint256, uint256
    }

    class Tick_Info {
        <<struct>>
        +liquidityGross uint128
        +liquidityNet int128
        +feeGrowthOutside0X128 uint256
        +feeGrowthOutside1X128 uint256
        +initialized bool
    }

    class Position {
        <<library>>
        +get(self, owner, tickLower, tickUpper) Info
        +update(info, liquidityDelta, feeGrowthInside0, feeGrowthInside1)
    }

    class Position_Info {
        <<struct>>
        +liquidity uint128
        +feeGrowthInside0LastX128 uint256
        +feeGrowthInside1LastX128 uint256
        +tokensOwed0 uint128
        +tokensOwed1 uint128
    }

    class Slot0 {
        <<struct>>
        +sqrtPriceX96 uint160
        +tick int24
        +unlocked bool
    }

    class CLFactory {
        <<contract>>
        +owner address
        +feeAmountTickSpacing mapping
        +getPool mapping
        +createPool(tokenA, tokenB, fee) address
        +enableFeeAmount(fee, tickSpacing)
    }

    class CLPool {
        <<contract>>
        +factory address$
        +token0 address$
        +token1 address$
        +fee uint24$
        +tickSpacing int24$
        +slot0 Slot0
        +liquidity uint128
        +feeGrowthGlobal0X128 uint256
        +feeGrowthGlobal1X128 uint256
        +tickBitmap mapping
        +ticks mapping
        +positions mapping
        +initialize(sqrtPriceX96)
        +mint(...)
        +burn(...)
        +collect(...)
        +swap(...)
    }

    class MockERC20 {
        <<contract mock>>
        +mint(to, amount)
        +burn(from, amount)
    }

    ICLFactory <|.. CLFactory : implements
    ICLPool <|.. CLPool : implements

    CLFactory --> CLPool : creates
    CLPool --> MockERC20 : transfers token0/1

    CLPool ..> FullMath : uses
    CLPool ..> TickMath : uses
    CLPool ..> SqrtPriceMath : uses
    CLPool ..> LiquidityMath : uses
    CLPool ..> SwapMath : uses
    CLPool ..> TickBitmap : uses
    CLPool ..> Tick : uses
    CLPool ..> Position : uses
    CLPool ..> CLErrors : reverts

    SwapMath ..> FullMath : uses
    SwapMath ..> SqrtPriceMath : uses
    SqrtPriceMath ..> FullMath : uses
    Tick ..> Tick_Info : manages
    Position ..> Position_Info : manages
    CLPool --> Slot0 : state
```

## Key relationships

| Relationship | Reason |
|--------------|--------|
| `CLFactory` → `CLPool` | One pool per `(token0, token1, fee)` |
| `CLPool` → math libs | Q64.96 price, amounts, and swap steps |
| `CLPool` → `TickBitmap` / `Tick` | Tick initialization and crossing |
| `CLPool` → `Position` | Liquidity and fees per `(owner, range)` |
| `SwapMath` → `SqrtPriceMath` | A step consumes/produces tokens up to the target |

## Design decisions (v1)

- No NFT Position Manager: positions indexed by `(owner, tickLower, tickUpper)`.
- Fee tiers with fixed `tickSpacing` via the factory (`enableFeeAmount`).
- `slot0` packs `sqrtPriceX96`, `tick`, and the lock (`unlocked`), Uniswap v3–style.
- Full flash swaps out of scope; `FlashSlippage` is reserved for compatibility with the module's error set.
- TWAP / observations: post-v1.

Spanish version: [`diagrama-de-clases-ES.md`](./diagrama-de-clases-ES.md)
