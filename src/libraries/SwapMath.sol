// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {FullMath} from "./FullMath.sol";
import {SqrtPriceMath} from "./SqrtPriceMath.sol";

/**
 * @title SwapMath
 * @notice Computa un step de swap dentro de un rango de precio (entre ticks).
 * @dev Adaptado de Uniswap v3-core (branch 0.8).
 */
library SwapMath {
    /**
     * @notice Resultado de un step de swap hacia un precio objetivo.
     * @dev Si amountRemaining > 0 es exact input; si < 0 es exact output.
     * @param sqrtRatioCurrentX96 Precio actual del pool.
     * @param sqrtRatioTargetX96 Precio que no se puede superar (define direccion).
     * @param liquidity Liquidez usable en el step.
     * @param amountRemaining Input restante (+) u output restante (-).
     * @param feePips Fee en hundredths of a bip (p. ej. 3000 = 0.30%).
     * @return sqrtRatioNextX96 Precio tras el step (<= target en magnitud de movimiento).
     * @return amountIn Token in consumido (sin fee separado).
     * @return amountOut Token out recibido.
     * @return feeAmount Fee tomado del input.
     */
    function computeSwapStep(
        uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
        uint128 liquidity,
        int256 amountRemaining,
        uint24 feePips
    ) internal pure returns (uint160 sqrtRatioNextX96, uint256 amountIn, uint256 amountOut, uint256 feeAmount) {
        unchecked {
            bool zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96;
            bool exactIn = amountRemaining >= 0;

            if (exactIn) {
                uint256 amountRemainingLessFee = FullMath.mulDiv(uint256(amountRemaining), 1e6 - feePips, 1e6);
                amountIn = zeroForOne
                    ? SqrtPriceMath.getAmount0Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true)
                    : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, true);
                if (amountRemainingLessFee >= amountIn) {
                    sqrtRatioNextX96 = sqrtRatioTargetX96;
                } else {
                    sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                        sqrtRatioCurrentX96, liquidity, amountRemainingLessFee, zeroForOne
                    );
                }
            } else {
                amountOut = zeroForOne
                    ? SqrtPriceMath.getAmount1Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, false)
                    : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, false);
                if (uint256(-amountRemaining) >= amountOut) {
                    sqrtRatioNextX96 = sqrtRatioTargetX96;
                } else {
                    sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(
                        sqrtRatioCurrentX96, liquidity, uint256(-amountRemaining), zeroForOne
                    );
                }
            }

            bool max = sqrtRatioTargetX96 == sqrtRatioNextX96;

            if (zeroForOne) {
                amountIn = max && exactIn
                    ? amountIn
                    : SqrtPriceMath.getAmount0Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true);
                amountOut = max && !exactIn
                    ? amountOut
                    : SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
            } else {
                amountIn = max && exactIn
                    ? amountIn
                    : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
                amountOut = max && !exactIn
                    ? amountOut
                    : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
            }

            if (!exactIn && amountOut > uint256(-amountRemaining)) {
                amountOut = uint256(-amountRemaining);
            }

            if (exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96) {
                feeAmount = uint256(amountRemaining) - amountIn;
            } else {
                feeAmount = FullMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
            }
        }
    }
}
