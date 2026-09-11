// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {DenominatorZero, FullMathOverflow} from "../errors/CLErrors.sol";

/**
 * @title FullMath
 * @notice Multiplicacion/division 512-bit con precision completa (phantom overflow).
 * @dev Credito: Remco Bloemen (MIT) / adaptado de Uniswap v3 para Solidity 0.8.24.
 *      https://xn--2-umb.com/21/muldiv
 */
library FullMath {
    /**
     * @notice Calcula floor(a * b / denominator) con precision completa.
     * @dev Revierte si denominator == 0 o el resultado desborda uint256.
     * @param a Multiplicando.
     * @param b Multiplicador.
     * @param denominator Divisor.
     * @return result Cociente redondeado hacia abajo.
     */
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = a * b
            uint256 prod0; // Least significant 256 bits
            uint256 prod1; // Most significant 256 bits
            assembly ("memory-safe") {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Non-overflow: 256 / 256 division
            if (prod1 == 0) {
                if (denominator == 0) revert DenominatorZero();
                assembly ("memory-safe") {
                    result := div(prod0, denominator)
                }
                return result;
            }

            // Ensure result < 2**256; also catches denominator == 0
            if (denominator <= prod1) revert FullMathOverflow();

            ///////////////////////////////////////////////
            // 512 by 256 division
            ///////////////////////////////////////////////

            uint256 remainder;
            assembly ("memory-safe") {
                remainder := mulmod(a, b, denominator)
            }
            assembly ("memory-safe") {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator
            uint256 twos = (0 - denominator) & denominator;
            assembly ("memory-safe") {
                denominator := div(denominator, twos)
            }
            assembly ("memory-safe") {
                prod0 := div(prod0, twos)
            }
            assembly ("memory-safe") {
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            // Invert denominator mod 2**256 (odd after removing factors of two)
            uint256 inv = (3 * denominator) ^ 2;
            inv *= 2 - denominator * inv; // inverse mod 2**8
            inv *= 2 - denominator * inv; // inverse mod 2**16
            inv *= 2 - denominator * inv; // inverse mod 2**32
            inv *= 2 - denominator * inv; // inverse mod 2**64
            inv *= 2 - denominator * inv; // inverse mod 2**128
            inv *= 2 - denominator * inv; // inverse mod 2**256

            result = prod0 * inv;
            return result;
        }
    }

    /**
     * @notice Calcula ceil(a * b / denominator) con precision completa.
     * @dev Revierte si denominator == 0 o el resultado desborda uint256.
     * @param a Multiplicando.
     * @param b Multiplicador.
     * @param denominator Divisor.
     * @return result Cociente redondeado hacia arriba.
     */
    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            result = mulDiv(a, b, denominator);
            if (mulmod(a, b, denominator) > 0) {
                if (result == type(uint256).max) revert FullMathOverflow();
                result++;
            }
        }
    }
}
