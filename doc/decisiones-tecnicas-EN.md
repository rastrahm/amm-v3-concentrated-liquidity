# Technical decisions, logic, and gas — AMM v3 Concentrated Liquidity

Explainer document for module 14 (v1 closed). Complements [`planificacion-EN.md`](./planificacion-EN.md), [`GAS-EN.md`](./GAS-EN.md), and [`diagrama-de-flujo-EN.md`](./diagrama-de-flujo-EN.md).

---

## 1. What problem it solves

A Uniswap v2–style AMM spreads liquidity across the **entire** price range. This module replicates the Uniswap v3 idea: the LP chooses an interval `[tickLower, tickUpper]` and concentrates capital where they expect volume. The pool quotes using $\sqrt{P}$ in **Q64.96** fixed point (`sqrtPriceX96`) and executes swaps **in steps**, crossing initialized ticks and shifting the active liquidity $L$.

---

## 2. Technical decisions (why it was built this way)

### 2.1 Uniswap v3–style architecture (core, not periphery)

| Decision | Reason |
|----------|--------|
| Separate **core** (`CLPool` / `CLFactory`) from periphery | The core is the liquidity engine; NFT/multi-hop routers are out of v1 scope. |
| Callbacks `clMintCallback` / `clSwapCallback` | The pool never calls `transferFrom` on the user: the caller (router) pays within the same tx, measured by **balance delta**. Uniswap pattern. |
| No NFT Position Manager | Positions live in a mapping keyed by `(owner, tickLower, tickUpper)`. Less code/gas in core. |
| No TWAP / observations | Fewer `SSTORE`s per swap; historical price oracle = post-v1. |
| No protocol fee | Fewer branches in fee growth; 100% of fees go to in-range LPs. |
| Flash swaps out of scope | The `FlashSlippage` error is reserved; there is no flash path in v1. |

### 2.2 Stack and monorepo rules

| Decision | Reason |
|----------|--------|
| Fixed `pragma solidity 0.8.24` | No floating pragma (SWC-103); same version in `foundry.toml`. |
| Custom errors (`CLErrors`) | Cheaper and typed compared to `require("…")`. |
| SafeERC20 (OZ v5) | Non-standard tokens (empty return values) do not break transfers. |
| Lock in `slot0.unlocked` | Uniswap-style anti-reentrancy (one slot with price/tick), no separate `ReentrancyGuard`. |
| Rounding **UP** on deposits / **DOWN** on withdrawals | Favors the pool; prevents draining the contract through dust. |
| Fuzz ≥ 1000 runs | Suite requirement; MIN/MAX ticks and amounts. |

### 2.3 Math and state

| Decision | Reason |
|----------|--------|
| Price as `sqrtPriceX96` (Q64.96) | Same representation as Uniswap v3: amounts are derived from differences of $\sqrt{P}$ and $1/\sqrt{P}$. |
| `FullMath.mulDiv` (512-bit) | Avoids intermediate overflow in fee growth and amounts. |
| `TickBitmap` (`mapping(int16 => uint256)`) | Finds the next initialized tick in **O(1) per word** (256 ticks). |
| Global fee growth + per-tick outside | Fees are accounted for without iterating positions; each position derives `feeGrowthInside`. |
| Factory fee tiers: 500/10, 3000/60, 10000/200 | Tick spacing coupled to the fee (as in Uniswap v3). |
| Factory with `new CLPool` (no CREATE2 deployer) | v1 simplicity; non-deterministic address, unlike Uniswap Factory+PoolDeployer. |

### 2.4 Security (design, not a “feature”)

| Decision | Reason |
|----------|--------|
| Validate ticks: `lower < upper`, MIN/MAX, `tickSpacing` | Prevents garbage ranges and a misaligned bitmap. |
| `sqrtPriceLimitX96` on swap | Slippage / direction; an invalid limit → `PriceTargetExceeded`. |
| Payment checked by post-callback balance | The pool does not trust the callback: it requires the balance to have increased by the requested amount. |
| Out-of-range → 0 fees | Only **active** liquidity (price inside the range) receives swap fee growth. |

---

## 3. System logic

### 3.1 Mental map

```
Factory.createPool(tokenA, tokenB, fee)
        │
        ▼
   CLPool (token0 < token1, fee, tickSpacing)
        │
        ├── initialize(sqrtPriceX96)     → slot0 (price, tick, unlocked)
        ├── mint  → _modifyPosition(+)  → payment callback → check balances
        ├── burn  → _modifyPosition(-)  → tokensOwed += amounts  (burn(0)=fee poke)
        ├── collect → decrease tokensOwed → safeTransfer
        └── swap  → step loop → transfer out → callback in → check balance
```

### 3.2 Where the liquidity is (golden rule)

Given a range `[P_lower, P_upper]` and liquidity $L$:

| Current price $P$ | What the LP provides | Counts as active L? |
|-------------------|----------------------|---------------------|
| $P \le P_{lower}$ | token0 only | No (has not entered the range yet) |
| $P_{lower} < P < P_{upper}$ | token0 + token1 | **Yes** (global `liquidity` += ΔL) |
| $P \ge P_{upper}$ | token1 only | No (already left the range) |

`SqrtPriceMath` computes this from `sqrtPriceX96` and $L$.

### 3.3 Mint (provide)

1. `lock` → prevents reentrancy.
2. Validates ticks / spacing / `amount > 0`.
3. Updates lower/upper ticks (`liquidityGross` / `liquidityNet`) and the bitmap if the tick goes from empty to used.
4. Updates `Position` (liquidity + fee growth inside).
5. If the price is **inside** the range, adds ΔL to global `liquidity`.
6. Computes `amount0` / `amount1` (rounding UP).
7. Callback to the caller → must transfer tokens to the pool.
8. Checks balances; if short → `InsufficientToken0/1`.

### 3.4 Burn + collect (withdraw)

1. Burn does **not** send tokens to the user: it accrues them in `tokensOwed*`.
2. `burn(0)` = **poke**: only syncs accrued fees into `tokensOwed` without moving L.
3. `collect` subtracts from `tokensOwed` and calls `safeTransfer` (CEI: debt first, then transfer).

### 3.5 Swap (multi-tick loop)

1. Validates `amountSpecified ≠ 0` and `sqrtPriceLimitX96` against direction and bounds.
2. While there is amount left and the price has not hit the limit:
   - Finds the **next initialized tick** in the bitmap.
   - Computes the step target (next tick vs price limit).
   - `SwapMath.computeSwapStep` → Δprice, amountIn, amountOut, fee.
   - Updates global fee growth (`fee / L` if $L > 0$).
   - If the step **reaches** the tick: `Tick.cross` and applies `liquidityNet` to active $L$.
3. Persists `slot0`, `liquidity`, `feeGrowthGlobal*`.
4. Transfers the output token to `recipient`.
5. Callback requests the input token; checks the balance.

Exact input: `amountSpecified > 0`. Exact output: `amountSpecified < 0` (same loop, signs inverted in the state).

### 3.6 Fees

- Each swap increments `feeGrowthGlobal0X128` or `feeGrowthGlobal1X128`.
- When a tick is crossed, `feeGrowthOutside` is stored.
- A position only “sees” the growth **inside** its range.
- If the price was never (or is not) inside its range during the swap, it earns **no** fees → validated in `OutOfRangeFees.t.sol`.

---

## 4. Can the existing gas be improved?

Yes. v1 already applies immutables, libraries, custom errors, the bitmap, and `via_ir`. Below: **realistic** improvements over this code, ordered by impact / risk.

### 4.1 Already applied (baseline)

See the numbers in [`GAS-EN.md`](./GAS-EN.md) (tests through a router; not “pure” pool gas).

| Technique | Effect |
|-----------|--------|
| Pool config `immutable` | Avoids SLOAD on the hot path |
| Math in libraries + `via_ir` + `optimizer_runs=10_000` | Aggressive inlining |
| Custom errors | Cheap reverts |
| Tick bitmap | Less linear tick search |
| Lock embedded in `slot0` | One storage slot vs a separate guard |
| No TWAP / protocol fee / NFT | Fewer writes per swap |

### 4.2 Possible improvements (v2 / hardening)

| Idea | Estimated impact | Risk / note |
|------|------------------|-------------|
| **Further packing of `Tick.Info` / `Position.Info`** | Medium on mint/burn/cross | Must respect a Uniswap-like layout; intensive fuzzing. |
| **More aggressive in-memory caching of `slot0` / `liquidity`** in swap | Low–medium | `SwapState` is already in memory; review residual SLOADs. |
| **Transient storage (Cancun) for the lock** | Low on the reentrancy path | `slot0.unlocked` would remain the Uniswap pattern; transient is a modern alternative. |
| **Assembly hot paths** (`SwapMath` / `SqrtPriceMath`) | Medium–high | Complexity and audit cost; Uniswap already uses selective assembly. |
| **Exact input-only API** (remove exact output branches) | Low–medium on bytecode/swap | Smaller surface; you lose native exact-out. |
| **Gas-aware periphery router** (batch mint+collect, multicall) | High *for the user* | Does not lower pool gas; lowers tx count / calldata. |
| **CREATE2 + PoolDeployer** | Deploy, not runtime | Predictable addresses; does not speed up swaps. |
| **Protocol fee off / sparse storage** | Already off | Keeping it off in v1 is correct for gas. |
| **Measure “pure” gas** (`vm.snapshotGas` / direct call without router) | Clarity | Current numbers include the helper hop; do not compare with Uniswap's published gas. |

### 4.3 What you should **not** “optimize” blindly

| Temptation | Why not |
|------------|---------|
| Removing the lock | Reentrancy via callback = theft / inconsistent state. |
| Rounding DOWN on mint | Drains the pool in favor of the LP (adversarial). |
| Skipping the post-callback balance check | You would be trusting a malicious router. |
| Iterating positions on every swap | Worse gas and does not scale. |
| Raising `optimizer_runs` without measuring | Can **worsen** runtime if it optimizes for deploy. |

### 4.4 Practical reading

1. The dominant cost of a **long swap** is not a micro-optimization: it is **how many ticks you cross**. Less liquidity fragmented across ticks = less gas.
2. The dominant cost of **mint** is writing ticks + position + the ERC-20 callback.
3. “Product-level” gas improvements (router, batching) usually give more UX than fighting for 200 gas in `mulDiv`.

---

## 5. Summarized flow (one sentence per operation)

| Operation | In one sentence |
|-----------|-----------------|
| `createPool` | Sorts tokens, looks up the fee tier, deploys `CLPool`. |
| `initialize` | Sets the first `sqrtPriceX96` / tick; opens the lock. |
| `mint` | Adds L to the range, charges tokens via callback. |
| `burn` | Removes L, credits tokens/fees into `tokensOwed`. |
| `collect` | Pays the user from `tokensOwed`. |
| `swap` | Moves the price in steps, distributes fees to active L, charges/pays via transfer + callback. |

---

## 6. Internal references

| Doc | Contents |
|-----|----------|
| [`planificacion-EN.md`](./planificacion-EN.md) | Phases 0–7, scope, criteria |
| [`diagrama-de-clases-EN.md`](./diagrama-de-clases-EN.md) | Contracts and libraries |
| [`diagrama-de-flujo-EN.md`](./diagrama-de-flujo-EN.md) | Mermaid mint/burn/swap/fees |
| [`flujograma-EN.md`](./flujograma-EN.md) | End-to-end actor–system |
| [`GAS-EN.md`](./GAS-EN.md) | Snapshot and tradeoffs |
| [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) | SWC-100–136 matrix |

Code: `src/CLPool.sol`, `src/CLFactory.sol`, `src/libraries/*`.

Spanish version: [`decisiones-tecnicas-ES.md`](./decisiones-tecnicas-ES.md)
