// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title CLErrors
 * @notice Custom errors del modulo AMM v3 Concentrated Liquidity.
 */

/// @notice Rango de ticks invalido (lower >= upper, fuera de limites, etc.).
error InvalidTickRange();

/// @notice Liquidez cero en mint/burn.
error ZeroLiquidity();

/// @notice El swap alcanzaria un precio fuera del limite permitido.
error PriceTargetExceeded();

/// @notice Slippage de flash swap incumplido.
error FlashSlippage();

/// @notice Direccion cero donde no se admite.
error ZeroAddress();

/// @notice Fee tier no habilitado o invalido.
error InvalidFee();

/// @notice sqrtPriceX96 fuera de [MIN_SQRT_RATIO, MAX_SQRT_RATIO).
error InvalidSqrtPrice();

/// @notice Tick fuera de [MIN_TICK, MAX_TICK].
error InvalidTick();

/// @notice Tick no alineado a tickSpacing.
error TickNotSpaced();

/// @notice Denominador cero en FullMath.
error DenominatorZero();

/// @notice Resultado de mulDiv desborda uint256.
error FullMathOverflow();

/// @notice Input insuficiente para el swap/step.
error InsufficientInputAmount();
