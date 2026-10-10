# Planning — Module 14: AMM v3 Concentrated Liquidity & Tick Math

**Status:** Phases **0–7** ✅ completed (v1 module closed).  
**Progress rule:** each phase requires **explicit authorization** from the owner before starting (*“I authorize Phase N”* or equivalent).

Spanish version: [`planificacion-ES.md`](./planificacion-ES.md)

---

## 1. Goal

Build a **concentrated liquidity AMM** engine (Uniswap v3 architecture) that supports:

- Liquidity provision in `[tickLower, tickUpper]` ranges with exact `token0` / `token1` calculation based on the current price position.
- **Q64.96** fixed-point math (`sqrtPriceX96`) via `FullMath` / `TickMath`.
- **Tick bitmap** (`mapping(int16 => uint256)`) for $O(1)$ lookup of the next initialized tick.
- **Step-wise** swaps crossing ticks, updating `feeGrowthGlobal*X128` and the active liquidity $L$.
- Stack: **Foundry + Solidity `0.8.24`** (fixed pragma).

---

## 2. Scope

| Included (v1) | Excluded (v1) |
|---------------|---------------|
| Concentrated pool: mint / burn / swap / collect fees | TWAP oracles / observations (post-v1) |
| Libs: `FullMath`, `TickMath`, `SqrtPriceMath`, `LiquidityMath`, `SwapMath`, `TickBitmap`, `Tick`, `Position` | NFT Position Manager (ERC-721) |
| Pool factory by `(token0, token1, fee)` | Multi-hop router / complex periphery |
| Global fee growth + per-position fees in the active range | Full flash swaps (only the `FlashSlippage` error if stubbed) |
| Tests: single-range, multi-tick swap, out-of-range = 0 fees, MIN/MAX tick fuzz | Next.js frontend |
| Module custom errors + CEI + NatSpec | On-chain fee governance |

---

## 3. Stack and technical constraints

### Suite (`evm-smart-contracts-suite`)

- **Exact** Solidity `0.8.24` (no floating pragma).
- OpenZeppelin Contracts v5.x (SafeERC20, ReentrancyGuard where applicable).
- Foundry: unit + fuzz (`runs >= 1000`) + gas reports.
- Custom errors (no `require` with strings).
- Strict CEI; ERC-20 transfers via SafeERC20; ETH via `.call{value}` if applicable.
- NatSpec on every public/external API.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.
- Rounding: **UP** on deposits (favors the pool); **DOWN** on withdrawals.

### Module 14 (Concentrated Liquidity)

- Internal price: $\sqrt{P}$ in **Q64.96** (`uint160 sqrtPriceX96`).
- Ticks: `MIN_TICK` / `MAX_TICK` aligned to the fee tier's spacing.
- Bitmap: `mapping(int16 => uint256) public tickBitmap`.
- Swap: step loop until `amountSpecified` is exhausted or `sqrtPriceLimitX96` is reached.
- Positions outside the active range: **zero** swap fees.

---

## 4. Architecture (v1 proposal)

```
14-amm-v3-concentrated-liquidity/
├── README.md                         # Language index (ES / EN)
├── README-ES.md / README-EN.md
├── doc/
│   ├── README.md                     # Language index (ES / EN)
│   ├── README-ES.md / README-EN.md
│   ├── planificacion-ES.md / -EN.md
│   ├── diagrama-de-clases-ES.md / -EN.md
│   ├── diagrama-de-flujo-ES.md / -EN.md
│   ├── flujograma-ES.md / -EN.md
│   ├── decisiones-tecnicas-ES.md / -EN.md
│   ├── GAS-ES.md / -EN.md
│   └── SWC-AUDIT-ES.md / -EN.md
├── src/
│   ├── CLPool.sol                    # Pool core: mint / burn / swap / collect
│   ├── CLFactory.sol                 # Creates pools by token0/token1/fee
│   ├── interfaces/
│   │   ├── ICLPool.sol
│   │   └── ICLFactory.sol
│   ├── libraries/
│   │   ├── FullMath.sol              # 512-bit mulDiv
│   │   ├── TickMath.sol              # tick ↔ sqrtPriceX96
│   │   ├── SqrtPriceMath.sol         # Δtoken0/1 given L and prices
│   │   ├── LiquidityMath.sol         # addDelta(L, ΔL)
│   │   ├── SwapMath.sol              # one swap step
│   │   ├── TickBitmap.sol            # nextInitializedTickWithinOneWord
│   │   ├── Tick.sol                  # update / cross tick
│   │   └── Position.sol              # position update + fees owed
│   ├── errors/
│   │   └── CLErrors.sol
│   └── mocks/
│       └── MockERC20.sol
├── test/
│   ├── helpers/CLTestBase.sol
│   ├── libraries/                    # unit tests per lib
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

### Contracts and responsibilities

| Artifact | Responsibility |
|----------|----------------|
| `FullMath` | `mulDiv` / `mulDivRoundingUp` without intermediate overflow |
| `TickMath` | `getSqrtRatioAtTick` / `getTickAtSqrtRatio`; `MIN_TICK` / `MAX_TICK` |
| `SqrtPriceMath` | `token0`/`token1` amounts between two $\sqrt{P}$ given $L$ |
| `LiquidityMath` | Safe addition/subtraction of active liquidity |
| `SwapMath` | Computes one step: target price, amounts in/out, fee |
| `TickBitmap` | Bit flip + next initialized tick within a word |
| `Tick` | `liquidityGross` / `liquidityNet` / `feeGrowthOutside`; `cross()` |
| `Position` | Key `(owner, tickLower, tickUpper)`; fees owed |
| `CLPool` | Global state, mint/burn/swap/collect |
| `CLFactory` | Deterministic pool deployment |
| `CLErrors` | Module custom errors |
| `MockERC20` | Test tokens |

---

## 5. Custom errors (module)

```solidity
error InvalidTickRange();
error ZeroLiquidity();
error PriceTargetExceeded();
error FlashSlippage();
```

Additional errors expected during implementation (documented when the phase is authorized):

```solidity
error ZeroAddress();
error InvalidFee();
error InvalidSqrtPrice();
error InsufficientInputAmount();
error TickNotSpaced();
```

---

## 6. Phase governance (mandatory authorization)

| Rule | Detail |
|------|--------|
| **Gate** | No code is written for a phase until: *“I authorize Phase N”*. |
| **Delivery** | On close: acceptance checklist + files touched. |
| **Blocking** | New scope → document it and wait for new authorization. |
| **TDD** | In contract phases: tests first, then implementation. |

### Phase board

| Phase | Name | Status | Authorization |
|-------|------|--------|---------------|
| 0 | Foundry setup + structure + deps | ✅ Completed | ✅ Authorized |
| 1 | Core math: `FullMath` + `TickMath` | ✅ Completed | ✅ Authorized |
| 2 | `SqrtPriceMath` + `LiquidityMath` + `SwapMath` | ✅ Completed | ✅ Authorized |
| 3 | `TickBitmap` + `Tick` + `Position` | ✅ Completed | ✅ Authorized |
| 4 | `CLPool` mint / burn / collect (no multi-tick swap) | ✅ Completed | ✅ Authorized |
| 5 | `CLPool` multi-tick swap + fee growth | ✅ Completed | ✅ Authorized |
| 6 | `CLFactory` + e2e / out-of-range / fuzz suite | ✅ Completed | ✅ Authorized |
| 7 | Gas + Deploy + NatSpec / SWC hardening | ✅ Completed | ✅ Authorized |

> **v1 module closed** (phases 0–7). Optional extensions → v2.

---

## 7. Phase details

### Phase 0 — Foundry setup ✅

**Goal:** compilable repo with the suite's tooling.

1. Foundry scaffold (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`).
2. Dependencies: `forge-std`, OpenZeppelin v5.
3. Folders `src/{interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas}`, `script/`, `doc/`.
4. Minimal stub + smoke test; `.env.example`.

**Exit criterion:** `forge build` and `forge test` green.

**Done (2026-09-11):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir`, fuzz `runs = 1000`, `[rpc_endpoints].mainnet`).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencies in `lib/` (gitignored, `--no-git --shallow`): `forge-std`, OpenZeppelin **v5.2.0**.
- Folders `src/{interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,gas,libraries}`, `script/`.
- Stub `src/Placeholder.sol` + `test/Placeholder.t.sol` (ping + IERC20 remapping).
- Stub `script/Deploy.s.sol` (Phase 7), `.env.example`, `README.md`.
- `forge build` OK; `forge test` → **3 PASS**.
- Note: use `~/.foundry/bin/forge` (the nvm/npm `forge` is not Foundry).

---

### Phase 1 — FullMath + TickMath ✅

**Goal:** Q64.96 math foundation and tick ↔ $\sqrt{P}$ conversion.

1. Tests first: `mulDiv`, rounding up/down, overflow edges.
2. `TickMath`: `getSqrtRatioAtTick` / `getTickAtSqrtRatio` at `MIN_TICK` / `MAX_TICK` and mid ticks.
3. Round-trip fuzz tick → sqrt → tick (no precision loss beyond what Uniswap documents).

**Exit criterion:** libs green; tick boundary fuzz OK.

**Done (2026-09-11):**
- `src/errors/CLErrors.sol`: module errors + `DenominatorZero`, `FullMathOverflow`, `InvalidTick`, `InvalidSqrtPrice`.
- `src/libraries/FullMath.sol`: `mulDiv` / `mulDivRoundingUp` (512-bit, Remco Bloemen / Uniswap v3 0.8).
- `src/libraries/TickMath.sol`: `MIN/MAX_TICK`, `MIN/MAX_SQRT_RATIO`, `getSqrtRatioAtTick`, `getTickAtSqrtRatio`.
- Tests: `test/libraries/FullMath.t.sol`, `test/libraries/TickMath.t.sol`, `test/fuzz/TickMath.fuzz.t.sol`.
- `Placeholder` stub removed.
- **`forge test` → 25 PASS** (incl. 1000-run fuzz).

---

### Phase 2 — SqrtPriceMath + LiquidityMath + SwapMath ✅

**Goal:** token amounts and one swap step.

1. Tests: amounts when $P$ is below / inside / above the range.
2. UP rounding on inputs to the pool; DOWN on outputs.
3. `SwapMath.computeSwapStep` with target price and fee.

**Exit criterion:** concentrated liquidity formulas verified against known cases.

**Done (2026-09-11):**
- Helpers: `FixedPoint96`, `UnsafeMath`, `SafeCast`.
- `LiquidityMath.addDelta` with `LiquidityOverflow` / `LiquidityUnderflow`.
- `SqrtPriceMath`: `getAmount0/1Delta`, `getNextSqrtPriceFromInput/Output` (custom errors).
- `SwapMath.computeSwapStep` (exact in/out, fee pips).
- New errors in `CLErrors`: `LiquidityUnderflow/Overflow`, `SafeCastOverflow`, `ZeroSqrtPriceOrLiquidity`.
- Tests: RareSkills vectors (499851), Uniswap next-from-output, rounding UP≥DOWN, swap step.
- **`forge test` → 49 PASS**.

---

### Phase 3 — TickBitmap + Tick + Position ✅

**Goal:** tick and position structures.

1. Bitmap: flip, next initialized (lte / gt).
2. `Tick.update` / `Tick.cross` with `liquidityNet` and `feeGrowthOutside`.
3. `Position.update` with fees owed based on fee growth inside.

**Exit criterion:** O(1) lookups and correct per-tick fee updates in unit tests.

**Done (2026-09-11):**
- Helpers: `BitMath`, `FixedPoint128`.
- `TickBitmap`: `flipTick`, `nextInitializedTickWithinOneWord` (`TickNotSpaced`).
- `Tick` (v1 without TWAP): `Info`, `update`, `cross`, `getFeeGrowthInside`, `clear`, `tickSpacingToMaxLiquidityPerTick`.
- `Position`: `get` by `(owner, lower, upper)`, `update` with fees owed (`NoLiquidityPosition`).
- Errors: `LiquidityGrossOverflow`, `NoLiquidityPosition`, `BitMathZero`.
- Tests with storage harnesses: bitmap lte/gt, feeGrowthInside, position fees.
- **`forge test` → 74 PASS**.

---

### Phase 4 — CLPool mint / burn / collect ✅

**Goal:** in-range liquidity provision and withdrawal (fixed price / no tick crossing in swaps).

1. TDD tests: single-range mint; burn; collect; `InvalidTickRange`; `ZeroLiquidity`.
2. Compute `amount0` / `amount1` based on where $P$ sits.
3. Update ticks + bitmap + position; transfer tokens (CEI + SafeERC20).

**Exit criterion:** single-range deposits/withdrawals green; rounding in favor of the pool.

**Done (2026-09-11):**
- `ICLPool`, `ICLMintCallback`, `MockERC20`, `CLPool` (initialize / mint / burn / collect + lock).
- Mint via `clMintCallback`; payment verified by balance.
- Amounts below / inside / above the range; global L only if P is inside.
- Burn credits `tokensOwed`; collect with SafeERC20.
- Errors: `AlreadyInitialized`, `Locked`, `InsufficientToken0/1`, `InvalidTokenOrder`.
- Tests: `test/CLPool.mint.t.sol` + `test/helpers/CLMintRouter.sol`.
- **`forge test` → 86 PASS**.

---

### Phase 5 — Multi-tick swap + fee growth ✅

**Goal:** iterative swap engine.

1. Tests: swap within a single tick; swap crossing N ticks; `sqrtPriceLimit`; `PriceTargetExceeded`.
2. Step loop: update price, L, `feeGrowthGlobal0X128` / `1X128`.
3. When crossing a tick: `Tick.cross` and adjust L with `liquidityNet`.

**Exit criterion:** multi-tick swaps + fee accrual in the active range.

**Done (2026-09-11):**
- `ICLSwapCallback` + `CLPool.swap` (exact in/out, no protocol fee / oracle).
- Step loop: bitmap → SwapMath → feeGrowthGlobal → cross + LiquidityMath.
- `burn(0)` enabled as a fee poke.
- `PriceTargetExceeded` on invalid limits; output via SafeERC20 + payment callback.
- Tests: `CLPool.swap.t.sol` + `CLSwapRouter` (1-tick, multi-tick, fees, limit).
- **`forge test` → 95 PASS**.

---

### Phase 6 — Factory + e2e / out-of-range / fuzz ✅

**Goal:** testing requirements from the module's `.cursorrules`.

| Type | What it validates |
|------|-------------------|
| Unit e2e | mint → swap → burn → collect |
| Out-of-range | position outside the active tick → **0 fees** |
| Fuzz | `MIN_TICK` / `MAX_TICK`, amounts, fee tiers |
| Factory | unique createPool; getPool |

**Exit criterion:** `forge test` green; fuzz ≥ 1000; out-of-range inactivity asserted.

**Done (2026-09-11):**
- `ICLFactory` + `CLFactory` (fees 500/3000/10000, createPool, enableFeeAmount, setOwner).
- Errors: `IdenticalAddresses`, `PoolAlreadyExists`, `Unauthorized`.
- Tests: `CLFactory.t.sol`, `OutOfRangeFees.t.sol`, `CLPool.e2e.t.sol`, `fuzz/CLPool.fuzz.t.sol`.
- `CLTestBase` helper (factory + pool + routers).
- **`forge test` → 112 PASS**.

---

### Phase 7 — Gas + Deploy + hardening ✅

1. `script/Deploy.s.sol` (factory + demo pool + mocks).
2. `test/gas/CLPool.gas.t.sol` + `.gas-snapshot`.
3. Complete NatSpec; `doc/SWC-AUDIT-*.md` and `doc/GAS-*.md`.

**Exit criterion:** reproducible local deploy + security/gas docs.

**Done (2026-09-11):**
- `script/Deploy.s.sol` — Factory + MockERC20 + pool + `initialize`.
- `test/gas/CLPool.gas.t.sol` + `.gas-snapshot` (6 paths).
- `doc/SWC-AUDIT-EN.md` — SWC-100–136 matrix, **0 vulnerable**, 4 informational.
- `doc/GAS-EN.md` — mint/swap/burn/poke/collect baseline.
- **`forge test` → 118 PASS**.

---

## 8. Test matrix (v1 target)

| Case | What it validates | Phase |
|------|-------------------|-------|
| Single-range mint | correct amounts below/inside/above | 4 |
| Burn + collect | DOWN withdrawals; fees owed | 4–5 |
| 1-tick swap | price and global fees | 5 |
| Multi-tick swap | L changes when crossing; amounts | 5 |
| Out-of-range fees | fees = 0 outside the range | 6 |
| InvalidTickRange / ZeroLiquidity | custom errors | 4 |
| PriceTargetExceeded | price limit on swap | 5 |
| MIN/MAX tick fuzz | Q64.96 precision | 1, 6 |
| Gas profiling | mint/swap/burn documented | 7 |

---

## 9. Security (living checklist)

- [x] CEI on mint / burn / swap / collect.
- [x] SafeERC20; no raw ETH `transfer`/`send`.
- [x] Module custom errors.
- [x] UP rounding on deposits / DOWN on withdrawals.
- [x] Validated ticks: lower < upper, spacing, bounds.
- [x] `sqrtPriceLimitX96` respected (`PriceTargetExceeded` where applicable).
- [x] Out-of-range positions do not accrue swap fees.
- [x] No floating pragma; NatSpec on public APIs.
- [x] Tick boundary fuzzing.
- [x] (Phase 7) SWC-AUDIT + gas.

---

## 10. Documentation deliverables (`doc/`)

Each document exists in Spanish (`-ES.md`) and English (`-EN.md`); `README.md` is the language index.

| File | Contents | Status |
|------|----------|--------|
| `README-EN.md` | Index | ✅ |
| `planificacion-EN.md` | This document | ✅ |
| `diagrama-de-clases-EN.md` | Structure and relationships | ✅ |
| `diagrama-de-flujo-EN.md` | Decision flows | ✅ |
| `flujograma-EN.md` | End-to-end actor–system flows | ✅ |
| `decisiones-tecnicas-EN.md` | Decisions, logic, and gas improvements | ✅ |
| `SWC-AUDIT-EN.md` | SWC matrix (Phase 7) | ✅ |
| `GAS-EN.md` | Benchmarks (Phase 7) | ✅ |

---

## 11. Module acceptance criteria

1. [x] Compiles with `pragma solidity 0.8.24`.
2. [x] Mint/burn with range math (below/inside/above).
3. [x] Multi-tick swap updating L and fee growth.
4. [x] Tick bitmap with O(1) next-initialized per word.
5. [x] Out-of-range → zero swap fees.
6. [x] MIN/MAX tick fuzz + Q64.96 precision.
7. [x] Custom errors + NatSpec.
8. [x] `doc/SWC-AUDIT-EN.md` with no vulnerabilities in v1 scope.

---

## 12. Next step

**v1 module closed.** Optional extensions (v2): NFT Position Manager, TWAP, flash swaps, Ownable2Step on the factory.

**Note:** use `~/.foundry/bin/forge` (or prepend `$HOME/.foundry/bin` to `PATH`); the nvm/npm `forge` is not Foundry.
