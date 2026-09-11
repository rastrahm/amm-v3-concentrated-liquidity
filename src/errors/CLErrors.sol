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

/// @notice Resta de liquidez provoca underflow.
error LiquidityUnderflow();

/// @notice Suma de liquidez provoca overflow.
error LiquidityOverflow();

/// @notice Cast seguro fuera de rango (uint160/int128/int256).
error SafeCastOverflow();

/// @notice Precio o liquidez cero donde se requiere > 0.
error ZeroSqrtPriceOrLiquidity();

/// @notice Liquidez bruta del tick excede el maximo por tick.
error LiquidityGrossOverflow();

/// @notice Poke de fees en posicion con liquidez cero.
error NoLiquidityPosition();

/// @notice BitMath llamado con x == 0.
error BitMathZero();

/// @notice Pool ya inicializado.
error AlreadyInitialized();

/// @notice Reentrancy / lock del pool.
error Locked();

/// @notice Callback de mint no pago suficiente token0.
error InsufficientToken0();

/// @notice Callback de mint no pago suficiente token1.
error InsufficientToken1();

/// @notice token0 debe ser address < token1.
error InvalidTokenOrder();
