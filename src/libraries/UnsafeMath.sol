// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

/**
 * @title UnsafeMath
 * @notice Operaciones matematicas sin chequeos de overflow/underflow.
 * @dev El caller debe validar inputs (p. ej. divisor != 0). Adaptado de Uniswap v3-core.
 */
library UnsafeMath {
    /**
     * @notice Retorna ceil(x / y).
     * @dev Division por 0 tiene comportamiento indefinido; validar externamente.
     * @param x Dividendo.
     * @param y Divisor.
     * @return z Cociente redondeado hacia arriba.
     */
    function divRoundingUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly ("memory-safe") {
            z := add(div(x, y), gt(mod(x, y), 0))
        }
    }
}
