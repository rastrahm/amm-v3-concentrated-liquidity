// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {FullMathOverflow, ZeroSqrtPriceOrLiquidity} from "../errors/CLErrors.sol";
import {FixedPoint96} from "./FixedPoint96.sol";
import {FullMath} from "./FullMath.sol";
import {SafeCast} from "./SafeCast.sol";
import {UnsafeMath} from "./UnsafeMath.sol";

/**
 * @title SqrtPriceMath
 * @notice Deltas de token0/token1 y siguiente precio dados L y sqrtPrice Q64.96.
 * @dev Adaptado de Uniswap v3-core (branch 0.8) a custom errors.
 *      Round UP en deposits/inputs al pool; DOWN en withdrawals/outputs.
 */
library SqrtPriceMath {
    using SafeCast for uint256;

    /**
     * @notice Siguiente sqrt price dado un delta de token0.
     * @dev Siempre redondea UP.
     * @param sqrtPX96 Precio actual.
     * @param liquidity Liquidez usable.
     * @param amount Delta de token0.
     * @param add true = anadir token0 (precio baja), false = quitar.
     * @return Precio resultante.
     */
    function getNextSqrtPriceFromAmount0RoundingUp(uint160 sqrtPX96, uint128 liquidity, uint256 amount, bool add)
        internal
        pure
        returns (uint160)
    {
        if (amount == 0) return sqrtPX96;
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;

        if (add) {
            unchecked {
                uint256 product;
                if ((product = amount * sqrtPX96) / amount == sqrtPX96) {
                    uint256 denominator = numerator1 + product;
                    if (denominator >= numerator1) {
                        return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator));
                    }
                }
            }
            return uint160(UnsafeMath.divRoundingUp(numerator1, (numerator1 / sqrtPX96) + amount));
        } else {
            unchecked {
                uint256 product;
                if (!((product = amount * sqrtPX96) / amount == sqrtPX96 && numerator1 > product)) {
                    revert FullMathOverflow();
                }
                uint256 denominator = numerator1 - product;
                return FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator).toUint160();
            }
        }
    }

    /**
     * @notice Siguiente sqrt price dado un delta de token1.
     * @dev Siempre redondea DOWN.
     * @param sqrtPX96 Precio actual.
     * @param liquidity Liquidez usable.
     * @param amount Delta de token1.
     * @param add true = anadir token1 (precio sube), false = quitar.
     * @return Precio resultante.
     */
    function getNextSqrtPriceFromAmount1RoundingDown(uint160 sqrtPX96, uint128 liquidity, uint256 amount, bool add)
        internal
        pure
        returns (uint160)
    {
        if (add) {
            uint256 quotient = (
                amount <= type(uint160).max
                    ? (amount << FixedPoint96.RESOLUTION) / liquidity
                    : FullMath.mulDiv(amount, FixedPoint96.Q96, liquidity)
            );
            return (uint256(sqrtPX96) + quotient).toUint160();
        } else {
            uint256 quotient = (
                amount <= type(uint160).max
                    ? UnsafeMath.divRoundingUp(amount << FixedPoint96.RESOLUTION, liquidity)
                    : FullMath.mulDivRoundingUp(amount, FixedPoint96.Q96, liquidity)
            );
            if (sqrtPX96 <= quotient) revert FullMathOverflow();
            unchecked {
                return uint160(sqrtPX96 - quotient);
            }
        }
    }

    /**
     * @notice Siguiente precio dado un amount in (exact input).
     * @param sqrtPX96 Precio actual.
     * @param liquidity Liquidez usable.
     * @param amountIn Cantidad de input.
     * @param zeroForOne true = token0 in (precio baja).
     * @return sqrtQX96 Precio tras el input.
     */
    function getNextSqrtPriceFromInput(uint160 sqrtPX96, uint128 liquidity, uint256 amountIn, bool zeroForOne)
        internal
        pure
        returns (uint160 sqrtQX96)
    {
        if (sqrtPX96 == 0 || liquidity == 0) revert ZeroSqrtPriceOrLiquidity();
        return zeroForOne
            ? getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
            : getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true);
    }

    /**
     * @notice Siguiente precio dado un amount out (exact output).
     * @param sqrtPX96 Precio actual.
     * @param liquidity Liquidez usable.
     * @param amountOut Cantidad de output.
     * @param zeroForOne true = token1 out (precio baja).
     * @return sqrtQX96 Precio tras el output.
     */
    function getNextSqrtPriceFromOutput(uint160 sqrtPX96, uint128 liquidity, uint256 amountOut, bool zeroForOne)
        internal
        pure
        returns (uint160 sqrtQX96)
    {
        if (sqrtPX96 == 0 || liquidity == 0) revert ZeroSqrtPriceOrLiquidity();
        return zeroForOne
            ? getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
            : getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false);
    }

    /**
     * @notice amount0 entre dos precios para liquidez L.
     * @dev amount0 = L * (1/sqrtA - 1/sqrtB) = L * (sqrtB - sqrtA) / (sqrtA * sqrtB).
     * @param sqrtRatioAX96 Precio A.
     * @param sqrtRatioBX96 Precio B.
     * @param liquidity Liquidez.
     * @param roundUp Redondeo hacia arriba si true.
     * @return amount0 Delta de token0.
     */
    function getAmount0Delta(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity, bool roundUp)
        internal
        pure
        returns (uint256 amount0)
    {
        unchecked {
            if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

            uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
            uint256 numerator2 = sqrtRatioBX96 - sqrtRatioAX96;

            if (sqrtRatioAX96 == 0) revert ZeroSqrtPriceOrLiquidity();

            return roundUp
                ? UnsafeMath.divRoundingUp(FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96), sqrtRatioAX96)
                : FullMath.mulDiv(numerator1, numerator2, sqrtRatioBX96) / sqrtRatioAX96;
        }
    }

    /**
     * @notice amount1 entre dos precios para liquidez L.
     * @dev amount1 = L * (sqrtB - sqrtA).
     * @param sqrtRatioAX96 Precio A.
     * @param sqrtRatioBX96 Precio B.
     * @param liquidity Liquidez.
     * @param roundUp Redondeo hacia arriba si true.
     * @return amount1 Delta de token1.
     */
    function getAmount1Delta(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity, bool roundUp)
        internal
        pure
        returns (uint256 amount1)
    {
        unchecked {
            if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

            return roundUp
                ? FullMath.mulDivRoundingUp(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96)
                : FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
        }
    }

    /**
     * @notice amount0 firmado segun liquidityDelta (mint UP / burn DOWN).
     * @param sqrtRatioAX96 Precio A.
     * @param sqrtRatioBX96 Precio B.
     * @param liquidity Delta de liquidez firmado.
     * @return amount0 Delta firmado de token0.
     */
    function getAmount0Delta(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, int128 liquidity)
        internal
        pure
        returns (int256 amount0)
    {
        unchecked {
            return liquidity < 0
                ? -getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
                : getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
        }
    }

    /**
     * @notice amount1 firmado segun liquidityDelta (mint UP / burn DOWN).
     * @param sqrtRatioAX96 Precio A.
     * @param sqrtRatioBX96 Precio B.
     * @param liquidity Delta de liquidez firmado.
     * @return amount1 Delta firmado de token1.
     */
    function getAmount1Delta(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, int128 liquidity)
        internal
        pure
        returns (int256 amount1)
    {
        unchecked {
            return liquidity < 0
                ? -getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
                : getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
        }
    }
}
