# SWC Audit — AMM v3 Concentrated Liquidity

Verification of the concentrated liquidity pool (Uniswap v3–style) against the [SWC Registry](https://swcregistry.io/) (EIP-1470) and monorepo principles (custom errors, fixed pragma, CEI, SafeERC20, lock, UP/DOWN rounding).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with [SCSVS](https://github.com/ComposableSecurity/SCSVS), [EEA EthTrust](https://entethalliance.org/specs/ethtrust/), and the [Uniswap v3 documentation](https://docs.uniswap.org/concepts/protocol/concentrated-liquidity).

**Audited contracts (prod / core):**  
`src/CLPool.sol`, `src/CLFactory.sol`,  
`src/libraries/{FullMath,TickMath,SqrtPriceMath,LiquidityMath,SwapMath,TickBitmap,Tick,Position,BitMath,SafeCast,UnsafeMath,FixedPoint96,FixedPoint128}.sol`,  
`src/interfaces/{ICLPool,ICLFactory,ICLMintCallback,ICLSwapCallback}.sol`,  
`src/errors/CLErrors.sol`

**Trusted dependencies (bugs outside our own scope):**  
OpenZeppelin Contracts v5.2.0 (`IERC20`, `SafeERC20`)

**Mocks (non-prod):** `src/mocks/MockERC20.sol`, routers in `test/helpers/`  
**Date:** 2026-09-11  
**Test references:** `test/CLPool.*.t.sol`, `test/CLFactory.t.sol`, `test/OutOfRangeFees.t.sol`,  
`test/fuzz/`, `test/gas/`, `test/libraries/`  
**Style:** aligned with [`13-decentralized-oracles/doc/SWC-AUDIT-EN.md`](../../13-decentralized-oracles/doc/SWC-AUDIT-EN.md)  
**Docs index:** [`README-EN.md`](./README-EN.md) · Module README: [`../README-EN.md`](../README-EN.md) · Spanish: [`SWC-AUDIT-ES.md`](./SWC-AUDIT-ES.md)

---

## Executive summary

| Status | Count |
|--------|-------|
| ✅ Mitigated / Not applicable | 32 |
| ⚠️ Informational (design / trust / ops) | 4 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities within the v1 scope (factory + pool mint/burn/collect/multi-tick swap). The module uses an **anti-reentrancy lock**, **SafeERC20**, **custom errors**, a **fixed `0.8.24` pragma**, tick/spacing/price-limit validation, and collects payments via **callback + balance delta**. Informational risks: MEV/transaction ordering on swaps, gas of multi-tick loops with many initialized ticks, centralized ownership in the factory, and `FlashSlippage` reserved without flash swaps in v1.

**Suite / module 14 principles verified:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `CLErrors` |
| Fixed pragma `0.8.24` | ✅ |
| CEI + `lock` on mint / burn / collect / swap | ✅ |
| SafeERC20 (no ETH `transfer`/`send`) | ✅ ERC-20 only; no ETH in core |
| UP rounding on deposits / DOWN on withdrawals | ✅ `SqrtPriceMath` / libs |
| Tick range + spacing + `PriceTargetExceeded` | ✅ |
| Out-of-range → 0 swap fees | ✅ `OutOfRangeFees.t.sol` |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |

---

## Full matrix SWC-100 — SWC-136

| ID | Title | Applies | Status | Evidence in AMM v3 |
|----|-------|---------|--------|--------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility in `src/` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; `FullMath` / `LiquidityMath` / `SafeCast` with errors; `unchecked` only where Uniswap math guarantees bounds |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` `solc = "0.8.24"` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) across `src/` |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | `SafeERC20.safeTransfer`; no ETH `.call` in core |
| SWC-105 | Unprotected Ether Withdrawal | No | N/A | Core does not handle ETH |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Yes | ✅ | `lock` modifier (`slot0.unlocked`) on mint/burn/collect/swap; callbacks run under lock; payments verified by post-callback balance |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Explicit `public` / `immutable` / storage mappings |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` (factory deploys with `new CLPool`) |
| SWC-113 | DoS with Failed Call | Partial | ✅ | Failed ERC-20 transfer reverts via SafeERC20; callback that does not pay → `InsufficientToken0/1` |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | Swaps/MEV; see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth via `msg.sender` (positions / factory owner) |
| SWC-116 | Block values as a proxy for time | No | N/A | No TWAP/oracle in v1; no timestamp-dependent logic |
| SWC-117 | Signature Malleability | No | N/A | No signatures |
| SWC-118 | Incorrect Constructor Name | No | N/A | 0.8+ `constructor` |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No state shadowing in core |
| SWC-120 | Weak Sources of Randomness | No | N/A | No RNG |
| SWC-121 | Missing Protection against Signature Replay | No | N/A | No signatures |
| SWC-122 | Lack of Proper Signature Verification | No | N/A | No signatures |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + unit / e2e / out-of-range / fuzz / gas |
| SWC-124 | Write to Arbitrary Storage Location | Partial | ✅ | Assembly in libs (`TickMath`, `FullMath`, `UnsafeMath`) is `memory-safe` / arithmetic; no arbitrary SSTORE |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | `CLPool is ICLPool`; `CLFactory is ICLFactory` |
| SWC-126 | Insufficient Gas Griefing | Partial | ⚠️ | A malicious callback can consume the caller's gas; see risks |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ⚠️ | Multi-tick swap: many initialized ticks → OOG (caller); Uniswap v3 pattern |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII in `src/` |
| SWC-131 | Presence of unused variables | Partial | ⚠️ | `FlashSlippage` reserved (no flash swaps in v1); no material dead code in active paths |
| SWC-132 | Unexpected Ether balance | No | N/A | No ETH in core |
| SWC-133 | Hash Collisions (var-length args) | Yes | ✅ | Position key `keccak256(abi.encodePacked(owner, tickLower, tickUpper))` — fixed-size types |
| SWC-134 | Message call with hardcoded gas | No | N/A | No hardcoded gas in calls |
| SWC-135 | Code With No Effects | No | N/A | No relevant no-ops in hot paths |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Pool/position state is public by AMM design |

---

## Informational risks

### SWC-114 — Transaction ordering / MEV

Whoever gets a swap included first moves `sqrtPriceX96` and fees. Front-running / sandwiching is a DeFi domain risk (same as Uniswap v3), not a bypass of pool invariants. User mitigation: strict `sqrtPriceLimitX96` and routers with slippage protection.

### SWC-126 / SWC-128 — callbacks and multi-tick loops

- The caller chooses the callback contract (`msg.sender` on mint/swap). A callback that runs out of gas or does heavy logic affects the caller, and does not break the lock (reentering the pool → `Locked()`).
- A swap that crosses many initialized ticks can approach the block gas limit. This is the trader's / router's responsibility (price limit, size).

### SWC-131 — `FlashSlippage` without a flash path

Error declared in `CLErrors` / `.cursorrules` for compatibility; full flash swaps are **out of v1 scope**. It is not an exploitable surface.

### Centralization / post-deploy trust

| Topic | Risk | v1 treatment |
|-------|------|--------------|
| `CLFactory.owner` | Can `enableFeeAmount` / `setOwner` | Owner = deployer; no Ownable2Step |
| Open `initialize` | Anyone sets the initial price once | Off-chain coordination / factory+script; `AlreadyInitialized` afterwards |
| Pool tokens | Non-standard tokens (fee-on-transfer, rebasing) can break balance deltas | Assume standard ERC-20; documented |
| Callbacks | A malicious router can lie to the user, not to the pool (the pool measures balances) | Trusted routers / periphery |

---

## Monorepo principles checklist (+ module 14)

| Principle | Compliant? | Notes |
|-----------|------------|-------|
| Custom errors | ✅ | `InvalidTickRange`, `ZeroLiquidity`, `PriceTargetExceeded`, `Locked`, … |
| CEI + reentrancy lock | ✅ | `lock` + state before callback; collect CEI (debt then transfer) |
| SafeERC20 | ✅ | `collect` / swap output |
| NatSpec on public/external | ✅ | Pool, factory, interfaces |
| Fuzz ≥ 1000 runs | ✅ | `CLPool.fuzz`, `TickMath.fuzz` |
| Out-of-range fees = 0 | ✅ | `OutOfRangeFees.t.sol` |
| No floating pragma | ✅ | `0.8.24` |
| No ETH `transfer`/`send` | ✅ | N/A in core |
| Gas profiling mint/swap/burn | ✅ | `doc/GAS-EN.md` |

---

## Verification findings (code)

### Confirmed mitigations

1. **CLPool.lock:** `unlocked` is false during mint/burn/collect/swap; reentry → `Locked()`.
2. **Mint/swap payments:** balance snapshot → callback → requires exact increase (`InsufficientToken0/1`).
3. **Collect:** decreases `tokensOwed*` before `safeTransfer` (CEI).
4. **Ticks:** `lower < upper`, `[MIN_TICK, MAX_TICK]`, alignment to `tickSpacing`.
5. **Swap:** validates `sqrtPriceLimitX96` against direction and bounds (`PriceTargetExceeded`); updates L when crossing initialized ticks and `feeGrowthGlobal*X128`.
6. **CLFactory:** sorts tokens, rejects identical tokens / invalid fee / duplicate pool; fee tiers 500/3000/10000.
7. **Math:** Q64.96 + `FullMath.mulDiv`; overflow/underflow surfaced as custom errors.
8. **E2E / fuzz / out-of-range / gas:** green suite (see results below).

### Phase 7 hardening

| # | Change | Reason |
|---|--------|--------|
| 1 | `script/Deploy.s.sol` | Reproducible local deploy (factory + mocks + pool + initialize) |
| 2 | `test/gas/CLPool.gas.t.sol` + `.gas-snapshot` | mint/swap/burn/poke/collect baseline |
| 3 | `doc/SWC-AUDIT-*.md` / `doc/GAS-*.md` | SWC-100–136 matrix + benchmarks |
| 4 | README / planning | Phase 7 module closure |

### Non-blocking observations (v2)

| # | Observation | Severity | Suggested action |
|---|-------------|----------|------------------|
| 1 | No NFT Position Manager | Info | ERC-721 periphery |
| 2 | No TWAP / observations | Info | Oracle slot as in Uniswap v3 |
| 3 | Factory owner without 2-step | Info | `Ownable2Step` |
| 4 | No flash swaps | Info | Implement + use `FlashSlippage` |
| 5 | Formal Foundry invariants | Improvement | Handler over pool + routers |

---

## SWC → tests mapping

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `FullMath.t.sol`, `LiquidityMath.t.sol`, `SqrtPriceMath.t.sol`, TickMath fuzz |
| SWC-103 | `forge build` fixed pragma |
| SWC-107 | mint/swap through routers; reentrancy via implicit lock on paths |
| SWC-114 | price limit in `CLPool.swap.t.sol` (`PriceTargetExceeded`) |
| SWC-123 | unit + e2e + factory + out-of-range + fuzz |
| Out-of-range fees | `OutOfRangeFees.t.sol` |
| Multi-tick / L | `CLPool.swap.t.sol`, `CLPool.e2e.t.sol` |
| Gas | `test/gas/CLPool.gas.t.sol` |

---

## Execution result

```text
forge test --summary
# 2026-09-11 Phase 7
CLFactoryTest          8 PASS
CLPoolE2ETest          1 PASS
CLPoolMintTest        12 PASS
CLPoolSwapTest         9 PASS
OutOfRangeFeesTest     3 PASS
CLPoolFuzzTest         5 PASS (1000 runs each)
TickMathFuzzTest       3 PASS (1000 runs each)
CLPoolGasTest          6 PASS
FullMathTest          10 PASS
LiquidityMathTest      6 PASS
PositionTest           6 PASS
SqrtPriceMathTest     12 PASS
SwapMathTest           6 PASS
TickTest              11 PASS
TickBitmapTest         8 PASS
TickMathTest          12 PASS
Total: 118 PASS / 0 FAIL / 0 SKIP
```

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [Uniswap v3 Core](https://github.com/Uniswap/v3-core)
- Module 13: [`13-decentralized-oracles/doc/SWC-AUDIT-EN.md`](../../13-decentralized-oracles/doc/SWC-AUDIT-EN.md)
- Gas: [`GAS-EN.md`](./GAS-EN.md)
- Plan: [`planificacion-EN.md`](./planificacion-EN.md)
