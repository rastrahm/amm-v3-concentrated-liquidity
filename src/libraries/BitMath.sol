// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {BitMathZero} from "../errors/CLErrors.sol";

/**
 * @title BitMath
 * @notice Indice del bit mas/menos significativo de un uint256.
 * @dev Adaptado de Uniswap v3-core a custom errors.
 */
library BitMath {
    /**
     * @notice Indice del bit mas significativo (LSB = 0, MSB = 255).
     * @dev Requiere x > 0. Cumple: x >= 2**r y x < 2**(r+1).
     * @param x Valor de entrada.
     * @return r Indice del MSB.
     */
    function mostSignificantBit(uint256 x) internal pure returns (uint8 r) {
        if (x == 0) revert BitMathZero();

        unchecked {
            if (x >= 0x100000000000000000000000000000000) {
                x >>= 128;
                r += 128;
            }
            if (x >= 0x10000000000000000) {
                x >>= 64;
                r += 64;
            }
            if (x >= 0x100000000) {
                x >>= 32;
                r += 32;
            }
            if (x >= 0x10000) {
                x >>= 16;
                r += 16;
            }
            if (x >= 0x100) {
                x >>= 8;
                r += 8;
            }
            if (x >= 0x10) {
                x >>= 4;
                r += 4;
            }
            if (x >= 0x4) {
                x >>= 2;
                r += 2;
            }
            if (x >= 0x2) r += 1;
        }
    }

    /**
     * @notice Indice del bit menos significativo (LSB = 0, MSB = 255).
     * @dev Requiere x > 0.
     * @param x Valor de entrada.
     * @return r Indice del LSB.
     */
    function leastSignificantBit(uint256 x) internal pure returns (uint8 r) {
        if (x == 0) revert BitMathZero();

        unchecked {
            r = 255;
            if (x & type(uint128).max > 0) {
                r -= 128;
            } else {
                x >>= 128;
            }
            if (x & type(uint64).max > 0) {
                r -= 64;
            } else {
                x >>= 64;
            }
            if (x & type(uint32).max > 0) {
                r -= 32;
            } else {
                x >>= 32;
            }
            if (x & type(uint16).max > 0) {
                r -= 16;
            } else {
                x >>= 16;
            }
            if (x & type(uint8).max > 0) {
                r -= 8;
            } else {
                x >>= 8;
            }
            if (x & 0xf > 0) {
                r -= 4;
            } else {
                x >>= 4;
            }
            if (x & 0x3 > 0) {
                r -= 2;
            } else {
                x >>= 2;
            }
            if (x & 0x1 > 0) r -= 1;
        }
    }
}
