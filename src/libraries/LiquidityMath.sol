// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {LiquidityOverflow, LiquidityUnderflow} from "../errors/CLErrors.sol";

/**
 * @title LiquidityMath
 * @notice Suma/resta segura de liquidez activa (uint128 + int128 delta).
 * @dev Adaptado de Uniswap v3-core a Solidity 0.8.24 con custom errors.
 */
library LiquidityMath {
    /**
     * @notice Aplica un delta firmado a la liquidez y revierte en overflow/underflow.
     * @param x Liquidez antes del cambio.
     * @param y Delta firmado (positivo = add, negativo = sub).
     * @return z Liquidez resultante.
     */
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            unchecked {
                z = x - uint128(-y);
            }
            if (z >= x) revert LiquidityUnderflow();
        } else {
            unchecked {
                z = x + uint128(y);
            }
            if (z < x) revert LiquidityOverflow();
        }
    }
}
