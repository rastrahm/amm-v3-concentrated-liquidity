# Gas optimization — AMM v3 Concentrated Liquidity

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract CLPoolGasTest --gas-report
forge snapshot --match-contract CLPoolGasTest
```

**Baseline date:** 2026-09-11 (Phase 7)  
**Snapshot:** `.gas-snapshot` (`test/gas/CLPool.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`

---

## Pool operations baseline

Measurement = gas of the **Foundry test** (includes the test router hop + callback). Orders of magnitude for comparing paths, not the exact cost of the pool's internal `SSTORE` alone.

| Path | Gas (snapshot) | Notes |
|------|----------------|-------|
| `testGas_mint_inRange` | **150 355** | Additional in-range mint (position already existed in setUp) |
| `testGas_swap_exactIn_oneForZero` | **101 435** | Exact input 1→0 |
| `testGas_collect` | **122 570** | Collect `tokensOwed` after poke |
| `testGas_burn` | **105 080** | Partial liquidity burn |
| `testGas_burn_poke` | **82 163** | `burn(0)` = update fees owed |
| `testGas_swap_exactIn_zeroForOne` | **77 198** | Exact input 0→1 (after prep swap in setUp) |

### Reading

- **Mint** is the most expensive path in the baseline (ticks/position + payment callback).
- **Swap** varies with direction and distance to the limit; the zeroForOne snapshot is cheaper after the setUp prep (less initialization work).
- **Poke** (`burn` with amount 0) avoids moving liquidity and only syncs fee growth → cheaper than a real burn.
- **Collect** includes two ERC-20 `safeTransfer` calls when both tokens are owed.

---

## Optimizations already applied in the module

| Technique | Where | Effect |
|-----------|-------|--------|
| `factory` / `token0` / `token1` / `fee` / `tickSpacing` / `maxLiquidityPerTick` **immutable** | `CLPool` | No config SLOAD on the hot path |
| Math in **libraries** | `SwapMath`, `SqrtPriceMath`, … | Inlining with optimizer / `via_ir` |
| Custom errors | `CLErrors` | Cheaper than `require` strings |
| Tick bitmap word lookup | `TickBitmap` | Next-initialized O(1) per word |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Aggressive inlining |
| Lock in `slot0.unlocked` | Uniswap-style | One slot shared with price/tick |

---

## Accepted tradeoffs

| Decision | Why |
|----------|-----|
| No NFT Position Manager | Less gas/code in core; periphery out of v1 scope |
| No TWAP / observations | Fewer SSTOREs per swap; oracle post-v1 |
| No protocol fee | Fewer branches in swap/fee growth |
| Mint/swap callbacks | Uniswap pattern; caller provides tokens in the same tx |
| Flash swaps out of v1 | Smaller surface; `FlashSlippage` error reserved |

---

## Deploy

```bash
# Local (factory + MockERC20 + initialized pool)
anvil   # another terminal
export PATH="$HOME/.foundry/bin:$PATH"
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Optional env: `PRIVATE_KEY`, `FEE` (default 3000), `INIT_TICK` (default 0). See `script/Deploy.s.sol` and `.env.example`.

README: [`../README-EN.md`](../README-EN.md) · Docs index: [`README-EN.md`](./README-EN.md) · Spanish: [`GAS-ES.md`](./GAS-ES.md)
