const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'AMM v3 Concentrated Liquidity — Rolando Strahm',
    'meta.description':
      'AMM Uniswap v3–style: liquidez concentrada, ticks Q64.96, gas snapshot y auditoría SWC. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Ataques',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 14 · PORTFOLIO WEB3',
    'hero.title': 'AMM V3<br>CONCENTRATED LIQUIDITY',
    'hero.role': 'Ticks · Q64.96 · Multi-tick swaps · Foundry · Solidity 0.8.24',
    'hero.sub':
      'Motor Uniswap v3–style: rangos de liquidez, tick bitmap, fee growth y swaps paso a paso; gas documentado y auditoría defensiva SWC-100–136.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Un AMM clásico (x·y=k) reparte liquidez en todo el precio. Este módulo construye un pool de <strong>liquidez concentrada</strong> (arquitectura Uniswap v3): LPs eligen rangos, el precio vive en <strong>Q64.96</strong>, y los swaps cruzan ticks actualizando L y fee growth. Cierre con <strong>gas snapshot</strong> y <strong>SWC</strong>.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'Pool concentrado',
    'p1.desc':
      'CLFactory + CLPool: mint / burn / collect / swap multi-tick, callbacks de pago y fee tiers 500 / 3000 / 10000.',
    'p1.l1': 'TickBitmap next-initialized O(1)',
    'p1.l2': 'FullMath · TickMath · SwapMath',
    'p1.l3': 'Out-of-range → 0 fees',
    'p2.num': '// PILAR_02',
    'p2.title': 'Optimización de gas',
    'p2.desc':
      'Immutables del pool, math en libraries, custom errors, tick bitmap y baseline mint/swap/burn en .gas-snapshot.',
    'p2.l1': 'Mint ~150k · Swap ~77–101k',
    'p2.l2': 'via_ir + optimizer 10k',
    'p2.l3': 'Lock en slot0.unlocked',
    'p3.num': '// PILAR_03',
    'p3.title': 'Verificación SWC',
    'p3.desc':
      'Matriz SWC-100–136 con foco en reentrancy (lock), SafeERC20, límites de precio y callbacks.',
    'p3.l1': '32 mitigados / N/A · 4 informativos',
    'p3.l2': '0 vulnerabilidades explotables',
    'p3.l3': '118 PASS · fuzz 1000',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Mint, swap, burn — medido',
    'gas.lead':
      'Fase 7: cada técnica está en <code>doc/GAS-ES.md</code> con su <strong>tradeoff</strong>. Baseline Foundry (incluye router de test + callback). Mint es el path más caro; poke (<code>burn(0)</code>) solo sincroniza fees.',
    'gas.bth1': 'Path',
    'gas.bth2': 'Gas (snapshot)',
    'gas.b1a': 'Mint in-range',
    'gas.b2a': 'Collect (tokensOwed)',
    'gas.b3a': 'Burn parcial',
    'gas.b4a': 'Swap exactIn 1→0',
    'gas.b5a': 'Poke burn(0) / Swap 0→1',
    'gas.th1': 'Optimización',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'factory / tokens / fee / tickSpacing / maxL immutable',
    'gas.r1b': 'Sin SLOAD de config en hot path',
    'gas.r2a': 'Math en libraries (SwapMath, SqrtPriceMath, …)',
    'gas.r2b': 'Inlining con optimizer / via_ir',
    'gas.r3a': 'Custom errors (CLErrors)',
    'gas.r3b': 'Reverts más baratos que require con strings',
    'gas.r4a': 'TickBitmap word lookup',
    'gas.r4b': 'Next-initialized O(1) por word',
    'gas.r5a': 'Lock en slot0.unlocked',
    'gas.r5b': 'Un slot compartido con precio/tick (estilo Uniswap)',
    'gas.r6a': 'Sin TWAP / protocol fee / NFT PM (v1)',
    'gas.r6b': 'Menos SSTORE y ramas en swap; periphery fuera de alcance',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Inlining agresivo; deploy un poco más caro a cambio de runtime',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz completa <strong>SWC-100 → SWC-136</strong> contra <code>CLPool</code>, <code>CLFactory</code> y libs. Informe en <code>doc/SWC-AUDIT-ES.md</code>. Conclusión: <strong>0 vulnerabilidades explotables</strong>; lock + SafeERC20 + callbacks con delta de balance.',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el contrato',
    'swc.r101': 'Solidity 0.8.24 + FullMath / LiquidityMath / SafeCast',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.r104': 'SafeERC20.safeTransfer; sin .call ETH en core',
    'swc.r107': 'lock (slot0.unlocked) en mint/burn/collect/swap; reentrada → Locked()',
    'swc.r123': 'Custom errors + unit / e2e / out-of-range / fuzz / gas',
    'swc.r133': 'Position key keccak256(owner, tickLower, tickUpper) — tipos fijos',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'MEV / orden de txs',
    'swc.i1d':
      'Quien swapear primero mueve el precio. Riesgo de dominio DeFi; mitigación de usuario: sqrtPriceLimitX96 y slippage en router.',
    'swc.i2t': 'Callbacks y multi-tick',
    'swc.i2d':
      'Callback pesado o muchos ticks inicializados pueden OOG al caller. El pool permanece bajo lock; no rompe invariantes.',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–7 cerradas',
    'pr.lead':
      'Desarrollo por gates: math Q64.96, libs de liquidez/swap, bitmap/ticks/posiciones, mint-burn, swap multi-tick, factory/e2e/fuzz y deploy + gas + SWC.',
    'ph.0': 'Bootstrap Foundry + OZ',
    'ph.12': 'FullMath/TickMath + Sqrt/Liq/SwapMath',
    'ph.34': 'Bitmap/Tick/Position + mint/burn/collect',
    'ph.56': 'Swap multi-tick + factory/e2e/fuzz',
    'ph.7': 'Deploy · gas · SWC',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC críticos',
    'st.4': 'Fuzz runs',
    'term.label': 'rolando@strahm:~/14-amm-v3-concentrated-liquidity',
    'term.1': 'forge test --summary',
    'term.2': '[PASS] suite · 118 passed',
    'term.3': 'cat doc/SWC-AUDIT-ES.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 4 · Mitigados/N/A: 32',
    'term.5': 'echo status',
    'term.6': 'MODULE_14_CLOSED · CL_AMM_V1',

    'at.eyebrow': '// 06 — CAMPAÑAS DEFENSIVAS',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'Suite e2e + fuzz: el “éxito” del ataque es que revierta o que los fees out-of-range sean cero. Sin PoCs de exploit — Locked, PriceTargetExceeded, InvalidTickRange, InsufficientToken*.',
    'cA.t': 'Reentrancy',
    'cA.d': 'Callback bajo lock → Locked() si reentra.',
    'cB.t': 'Price limit',
    'cB.d': 'sqrtPriceLimit inválido → PriceTargetExceeded.',
    'cC.t': 'Out-of-range',
    'cC.d': 'Posición fuera del tick activo → 0 fees.',
    'cD.t': 'Bad payment',
    'cD.d': 'Callback sin tokens → InsufficientToken0/1.',
    'cE.t': 'Tick fuzz',
    'cE.d': 'MIN/MAX tick y spacing sin pérdida Q64.96.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'El mismo código está en GitHub y GitLab: pool, factory, libs, tests, gas, auditoría SWC y diagramas.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — AMM v3 Concentrated Liquidity · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'AMM v3 Concentrated Liquidity — Rolando Strahm',
    'meta.description':
      'Uniswap v3–style AMM: concentrated liquidity, Q64.96 ticks, gas snapshot, and SWC audit. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Attacks',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 14 · WEB3 PORTFOLIO',
    'hero.title': 'AMM V3<br>CONCENTRATED LIQUIDITY',
    'hero.role': 'Ticks · Q64.96 · Multi-tick swaps · Foundry · Solidity 0.8.24',
    'hero.sub':
      'Uniswap v3–style engine: liquidity ranges, tick bitmap, fee growth, and step-wise swaps; documented gas and defensive SWC-100–136 audit.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'A classic AMM (x·y=k) spreads liquidity across the entire price curve. This module builds a <strong>concentrated liquidity</strong> pool (Uniswap v3 architecture): LPs choose ranges, price lives in <strong>Q64.96</strong>, and swaps cross ticks updating L and fee growth. Closed with a <strong>gas snapshot</strong> and <strong>SWC</strong>.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module ships',
    'p1.num': '// PILLAR_01',
    'p1.title': 'Concentrated pool',
    'p1.desc':
      'CLFactory + CLPool: mint / burn / collect / multi-tick swap, payment callbacks, and fee tiers 500 / 3000 / 10000.',
    'p1.l1': 'TickBitmap next-initialized O(1)',
    'p1.l2': 'FullMath · TickMath · SwapMath',
    'p1.l3': 'Out-of-range → 0 fees',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Gas optimization',
    'p2.desc':
      'Pool immutables, math libraries, custom errors, tick bitmap, and mint/swap/burn baseline in .gas-snapshot.',
    'p2.l1': 'Mint ~150k · Swap ~77–101k',
    'p2.l2': 'via_ir + optimizer 10k',
    'p2.l3': 'Lock on slot0.unlocked',
    'p3.num': '// PILLAR_03',
    'p3.title': 'SWC verification',
    'p3.desc':
      'SWC-100–136 matrix focused on reentrancy (lock), SafeERC20, price limits, and callbacks.',
    'p3.l1': '32 mitigated / N/A · 4 informational',
    'p3.l2': '0 exploitable vulnerabilities',
    'p3.l3': '118 PASS · fuzz 1000',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Mint, swap, burn — measured',
    'gas.lead':
      'Phase 7: every technique is in <code>doc/GAS-EN.md</code> with its <strong>tradeoff</strong>. Foundry baseline (includes test router + callback). Mint is the heaviest path; poke (<code>burn(0)</code>) only syncs fees.',
    'gas.bth1': 'Path',
    'gas.bth2': 'Gas (snapshot)',
    'gas.b1a': 'Mint in-range',
    'gas.b2a': 'Collect (tokensOwed)',
    'gas.b3a': 'Partial burn',
    'gas.b4a': 'Swap exactIn 1→0',
    'gas.b5a': 'Poke burn(0) / Swap 0→1',
    'gas.th1': 'Optimization',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'factory / tokens / fee / tickSpacing / maxL immutable',
    'gas.r1b': 'No config SLOAD on the hot path',
    'gas.r2a': 'Math in libraries (SwapMath, SqrtPriceMath, …)',
    'gas.r2b': 'Inlining with optimizer / via_ir',
    'gas.r3a': 'Custom errors (CLErrors)',
    'gas.r3b': 'Cheaper reverts than require strings',
    'gas.r4a': 'TickBitmap word lookup',
    'gas.r4b': 'Next-initialized O(1) per word',
    'gas.r5a': 'Lock on slot0.unlocked',
    'gas.r5b': 'One shared slot with price/tick (Uniswap-style)',
    'gas.r6a': 'No TWAP / protocol fee / NFT PM (v1)',
    'gas.r6b': 'Fewer SSTOREs and swap branches; periphery out of scope',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Aggressive inlining; slightly dearer deploy for cheaper runtime',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Full matrix <strong>SWC-100 → SWC-136</strong> against <code>CLPool</code>, <code>CLFactory</code>, and libs. Report in <code>doc/SWC-AUDIT-EN.md</code>. Conclusion: <strong>0 exploitable vulnerabilities</strong>; lock + SafeERC20 + balance-delta callbacks.',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the contract',
    'swc.r101': 'Solidity 0.8.24 + FullMath / LiquidityMath / SafeCast',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.r104': 'SafeERC20.safeTransfer; no ETH .call in core',
    'swc.r107': 'lock (slot0.unlocked) on mint/burn/collect/swap; reentry → Locked()',
    'swc.r123': 'Custom errors + unit / e2e / out-of-range / fuzz / gas',
    'swc.r133': 'Position key keccak256(owner, tickLower, tickUpper) — fixed types',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'MEV / tx ordering',
    'swc.i1d':
      'Whoever swaps first moves the price. DeFi domain risk; user mitigation: sqrtPriceLimitX96 and router slippage.',
    'swc.i2t': 'Callbacks & multi-tick',
    'swc.i2d':
      'A heavy callback or many initialized ticks can OOG the caller. The pool stays under lock; invariants hold.',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–7 closed',
    'pr.lead':
      'Approval-gated delivery: Q64.96 math, liquidity/swap libs, bitmap/ticks/positions, mint-burn, multi-tick swap, factory/e2e/fuzz, then deploy + gas + SWC.',
    'ph.0': 'Foundry bootstrap + OZ',
    'ph.12': 'FullMath/TickMath + Sqrt/Liq/SwapMath',
    'ph.34': 'Bitmap/Tick/Position + mint/burn/collect',
    'ph.56': 'Multi-tick swap + factory/e2e/fuzz',
    'ph.7': 'Deploy · gas · SWC',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'Critical SWC',
    'st.4': 'Fuzz runs',
    'term.label': 'rolando@strahm:~/14-amm-v3-concentrated-liquidity',
    'term.1': 'forge test --summary',
    'term.2': '[PASS] suite · 118 passed',
    'term.3': 'cat doc/SWC-AUDIT-EN.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 4 · Mitigated/N/A: 32',
    'term.5': 'echo status',
    'term.6': 'MODULE_14_CLOSED · CL_AMM_V1',

    'at.eyebrow': '// 06 — DEFENSIVE CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'E2E + fuzz suite: a successful “attack” means a revert or zero out-of-range fees. No exploit PoCs — Locked, PriceTargetExceeded, InvalidTickRange, InsufficientToken*.',
    'cA.t': 'Reentrancy',
    'cA.d': 'Callback under lock → Locked() on reentry.',
    'cB.t': 'Price limit',
    'cB.d': 'Invalid sqrtPriceLimit → PriceTargetExceeded.',
    'cC.t': 'Out-of-range',
    'cC.d': 'Position outside active tick → 0 fees.',
    'cD.t': 'Bad payment',
    'cD.d': 'Callback without tokens → InsufficientToken0/1.',
    'cE.t': 'Tick fuzz',
    'cE.d': 'MIN/MAX tick and spacing with no Q64.96 loss.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'The same codebase is on GitHub and GitLab: pool, factory, libs, tests, gas, SWC audit, and diagrams.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — AMM v3 Concentrated Liquidity · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },
};

function setLanguage(lang) {
  const dict = I18N[lang] || I18N.es;
  document.documentElement.lang = dict['html.lang'];
  document.title = dict['meta.title'];

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc && dict['meta.description']) {
    metaDesc.setAttribute('content', dict['meta.description']);
  }

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const val = dict[key];
    if (val == null) return;
    if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
    else el.textContent = val;
  });

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });

  localStorage.setItem('amm-v3-portfolio-lang', lang);

  const url = new URL(window.location.href);
  url.searchParams.set('lang', lang);
  history.replaceState(null, '', url);
}

function initI18n() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get('lang');
  const saved = localStorage.getItem('amm-v3-portfolio-lang');
  const preferred =
    (fromQuery === 'en' || fromQuery === 'es' ? fromQuery : null) ||
    saved ||
    (navigator.language?.startsWith('en') ? 'en' : 'es');

  setLanguage(preferred);

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => setLanguage(btn.dataset.lang));
  });
}

document.addEventListener('DOMContentLoaded', initI18n);
