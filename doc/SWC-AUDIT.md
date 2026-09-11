# Auditoría SWC — AMM v3 Concentrated Liquidity

Verificación del pool de liquidez concentrada (Uniswap v3–style) contra el [SWC Registry](https://swcregistry.io/) (EIP-1470) y principios del monorepo (custom errors, pragma fijo, CEI, SafeERC20, lock, redondeo UP/DOWN).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS), [EEA EthTrust](https://entethalliance.org/specs/ethtrust/) y la [documentación de Uniswap v3](https://docs.uniswap.org/concepts/protocol/concentrated-liquidity).

**Contratos auditados (prod / core):**  
`src/CLPool.sol`, `src/CLFactory.sol`,  
`src/libraries/{FullMath,TickMath,SqrtPriceMath,LiquidityMath,SwapMath,TickBitmap,Tick,Position,BitMath,SafeCast,UnsafeMath,FixedPoint96,FixedPoint128}.sol`,  
`src/interfaces/{ICLPool,ICLFactory,ICLMintCallback,ICLSwapCallback}.sol`,  
`src/errors/CLErrors.sol`

**Dependencias de confianza (fuera de alcance de bugs propios):**  
OpenZeppelin Contracts v5.2.0 (`IERC20`, `SafeERC20`)

**Mocks (fuera de prod):** `src/mocks/MockERC20.sol`, routers en `test/helpers/`  
**Fecha:** 2026-09-11  
**Referencia tests:** `test/CLPool.*.t.sol`, `test/CLFactory.t.sol`, `test/OutOfRangeFees.t.sol`,  
`test/fuzz/`, `test/gas/`, `test/libraries/`  
**Estilo:** alineado a [`13-decentralized-oracles/doc/SWC-AUDIT.md`](../../13-decentralized-oracles/doc/SWC-AUDIT.md)  
**Índice docs:** [`README.md`](./README.md) · README módulo: [`../README.md`](../README.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 32 |
| ⚠️ Informativo (diseño / trust / ops) | 4 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1 (factory + pool mint/burn/collect/swap multi-tick). El módulo usa **lock anti-reentrancy**, **SafeERC20**, **custom errors**, **pragma fijo `0.8.24`**, validación de ticks/spacing/límites de precio, y cobra pagos vía **callback + delta de balance**. Riesgos informativos: MEV/orden de txs en swaps, gas de loops multi-tick con muchos ticks inicializados, ownership centralizado en la factory, y `FlashSlippage` reservado sin flash swaps en v1.

**Principios del suite / módulo 14 verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `CLErrors` |
| Pragma fijo `0.8.24` | ✅ |
| CEI + `lock` en mint / burn / collect / swap | ✅ |
| SafeERC20 (sin `transfer`/`send` ETH) | ✅ Solo ERC-20; sin ETH en core |
| Redondeo UP depósitos / DOWN retiros | ✅ `SqrtPriceMath` / libs |
| Tick range + spacing + `PriceTargetExceeded` | ✅ |
| Out-of-range → 0 swap fees | ✅ `OutOfRangeFees.t.sol` |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + `test/fuzz/` |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en AMM v3 |
|----|--------|--------|--------|---------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en `src/` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; `FullMath` / `LiquidityMath` / `SafeCast` con errores; `unchecked` solo donde la matemática Uniswap garantiza bounds |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` `solc = "0.8.24"` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) en todo `src/` |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | `SafeERC20.safeTransfer`; sin `.call` ETH en core |
| SWC-105 | Unprotected Ether Withdrawal | No | N/A | Core no maneja ETH |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Sí | ✅ | Modifier `lock` (`slot0.unlocked`) en mint/burn/collect/swap; callbacks bajo lock; pagos verificados por balance post-callback |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | `public` / `immutable` / storage mappings explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` (factory crea con `new CLPool`) |
| SWC-113 | DoS with Failed Call | Parcial | ✅ | Transfer ERC-20 fallida revierte vía SafeERC20; callback que no paga → `InsufficientToken0/1` |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Swaps/MEV; ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth por `msg.sender` (posiciones / factory owner) |
| SWC-116 | Block values as a proxy for time | No | N/A | Sin TWAP/oracle en v1; sin lógica dependiente de timestamp |
| SWC-117 | Signature Malleability | No | N/A | Sin firmas |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing de estado en core |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG |
| SWC-121 | Missing Protection against Signature Replay | No | N/A | Sin firmas |
| SWC-122 | Lack of Proper Signature Verification | No | N/A | Sin firmas |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + unit / e2e / out-of-range / fuzz / gas |
| SWC-124 | Write to Arbitrary Storage Location | Parcial | ✅ | Assembly en libs (`TickMath`, `FullMath`, `UnsafeMath`) es `memory-safe` / aritmética; sin SSTORE arbitrario |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | `CLPool is ICLPool`; `CLFactory is ICLFactory` |
| SWC-126 | Insufficient Gas Griefing | Parcial | ⚠️ | Callback malicioso puede consumir gas del caller; ver riesgos |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ⚠️ | Swap multi-tick: muchos ticks inicializados → OOG (caller); patrón Uniswap v3 |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII en `src/` |
| SWC-131 | Presence of unused variables | Parcial | ⚠️ | `FlashSlippage` reservado (sin flash swaps v1); sin dead code material en paths activos |
| SWC-132 | Unexpected Ether balance | No | N/A | Sin ETH en core |
| SWC-133 | Hash Collisions (var-length args) | Sí | ✅ | Position key `keccak256(abi.encodePacked(owner, tickLower, tickUpper))` — tipos fijos |
| SWC-134 | Message call with hardcoded gas | No | N/A | Sin gas hardcodeado en calls |
| SWC-135 | Code With No Effects | No | N/A | Sin no-ops relevantes en hot paths |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | Estado de pool/posiciones público por diseño AMM |

---

## Riesgos informativos

### SWC-114 — Orden de transacciones / MEV

Quien incluye primero un swap mueve `sqrtPriceX96` y fees. Front-running / sandwich es riesgo de dominio DeFi (igual que Uniswap v3), no un bypass de invariantes del pool. Mitigación de usuario: `sqrtPriceLimitX96` estricto y routers con slippage.

### SWC-126 / SWC-128 — callbacks y loops multi-tick

- El caller elige el contrato de callback (`msg.sender` en mint/swap). Un callback que hace OOG o lógica pesada afecta al caller, no rompe el lock (reentrancy al pool → `Locked()`).
- Un swap que cruza muchos ticks inicializados puede acercarse al block gas limit. Responsabilidad del trader / router (límite de precio, tamaño).

### SWC-131 — `FlashSlippage` sin flash path

Error declarado en `CLErrors` / `.cursorrules` para compatibilidad; flash swaps completos están **fuera de alcance v1**. No es una superficie explotable.

### Centralización / trust post-deploy

| Tema | Riesgo | Tratamiento v1 |
|------|--------|----------------|
| `CLFactory.owner` | Puede `enableFeeAmount` / `setOwner` | Owner = deployer; sin Ownable2Step |
| `initialize` abierto | Cualquiera fija el precio inicial una vez | Coordinación off-chain / factory+script; `AlreadyInitialized` después |
| Tokens del pool | Tokens no estándar (fee-on-transfer, rebase) pueden romper deltas de balance | Asumir ERC-20 estándar; documentar |
| Callbacks | Router malicioso puede mentir al usuario, no al pool (pool mide balances) | Routers de confianza / periphery |

---

## Checklist principios monorepo (+ módulo 14)

| Principio | ¿Cumple? | Notas |
|-----------|----------|--------|
| Custom errors | ✅ | `InvalidTickRange`, `ZeroLiquidity`, `PriceTargetExceeded`, `Locked`, … |
| CEI + reentrancy lock | ✅ | `lock` + estado antes de callback; collect CEI (deuda luego transfer) |
| SafeERC20 | ✅ | `collect` / salida de swap |
| NatSpec públicas/externas | ✅ | Pool, factory, interfaces |
| Fuzz ≥ 1000 runs | ✅ | `CLPool.fuzz`, `TickMath.fuzz` |
| Out-of-range fees = 0 | ✅ | `OutOfRangeFees.t.sol` |
| Sin floating pragma | ✅ | `0.8.24` |
| Sin ETH `transfer`/`send` | ✅ | N/A core |
| Gas profiling mint/swap/burn | ✅ | `doc/GAS.md` |

---

## Hallazgos de verificación (código)

### Mitigaciones confirmadas

1. **CLPool.lock:** `unlocked` false durante mint/burn/collect/swap; reentrada → `Locked()`.
2. **Mint/swap pagos:** snapshot de balance → callback → exige incremento exacto (`InsufficientToken0/1`).
3. **Collect:** reduce `tokensOwed*` antes de `safeTransfer` (CEI).
4. **Ticks:** `lower < upper`, `[MIN_TICK, MAX_TICK]`, alineación a `tickSpacing`.
5. **Swap:** valida `sqrtPriceLimitX96` vs dirección y bounds (`PriceTargetExceeded`); actualiza L al cruzar ticks inicializados y `feeGrowthGlobal*X128`.
6. **CLFactory:** ordena tokens, rechaza idénticos / fee inválido / pool duplicado; fee tiers 500/3000/10000.
7. **Math:** Q64.96 + `FullMath.mulDiv`; overflow/underflow liquified → custom errors.
8. **E2E / fuzz / out-of-range / gas:** suite verde (ver resultado abajo).

### Hardening Fase 7

| # | Cambio | Motivo |
|---|--------|--------|
| 1 | `script/Deploy.s.sol` | Deploy reproducible local (factory + mocks + pool + initialize) |
| 2 | `test/gas/CLPool.gas.t.sol` + `.gas-snapshot` | Baseline mint/swap/burn/poke/collect |
| 3 | `doc/SWC-AUDIT.md` / `doc/GAS.md` | Matriz SWC-100–136 + benchmarks |
| 4 | README / planificacion | Cierre módulo Fase 7 |

### Observaciones no bloqueantes (v2)

| # | Observación | Severidad | Acción sugerida |
|---|-------------|---------|-----------------|
| 1 | Sin NFT Position Manager | Info | Periphery ERC-721 |
| 2 | Sin TWAP / observations | Info | Oracle slot como Uniswap v3 |
| 3 | Factory owner sin 2-step | Info | `Ownable2Step` |
| 4 | Sin flash swaps | Info | Implementar + usar `FlashSlippage` |
| 5 | Invariantes Foundry formales | Mejora | Handler sobre pool + routers |

---

## Mapeo SWC → tests

| SWC | Test(s) |
|-----|---------|
| SWC-101 | `FullMath.t.sol`, `LiquidityMath.t.sol`, `SqrtPriceMath.t.sol`, fuzz TickMath |
| SWC-103 | `forge build` pragma fijo |
| SWC-107 | mint/swap con routers; reentrancy vía lock implícito en paths |
| SWC-114 | límite de precio en `CLPool.swap.t.sol` (`PriceTargetExceeded`) |
| SWC-123 | unit + e2e + factory + out-of-range + fuzz |
| Fees out-of-range | `OutOfRangeFees.t.sol` |
| Multi-tick / L | `CLPool.swap.t.sol`, `CLPool.e2e.t.sol` |
| Gas | `test/gas/CLPool.gas.t.sol` |

---

## Resultado de ejecución

```text
forge test --summary
# 2026-09-11 Fase 7
CLFactoryTest          8 PASS
CLPoolE2ETest          1 PASS
CLPoolMintTest        12 PASS
CLPoolSwapTest         9 PASS
OutOfRangeFeesTest     3 PASS
CLPoolFuzzTest         5 PASS (1000 runs c/u)
TickMathFuzzTest       3 PASS (1000 runs c/u)
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

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- [Uniswap v3 Core](https://github.com/Uniswap/v3-core)
- Módulo 13: [`13-decentralized-oracles/doc/SWC-AUDIT.md`](../../13-decentralized-oracles/doc/SWC-AUDIT.md)
- Gas: [`GAS.md`](./GAS.md)
- Plan: [`planificacion.md`](./planificacion.md)
