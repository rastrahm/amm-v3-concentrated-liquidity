// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {SafeCastOverflow} from "../errors/CLErrors.sol";

/**
 * @title SafeCast
 * @notice Casts seguros entre tipos enteros.
 * @dev Adaptado de Uniswap v3-core a custom errors.
 */
library SafeCast {
    /**
     * @notice Cast uint256 -> uint160; revierte en overflow.
     * @param y Valor a castear.
     * @return z Valor uint160.
     */
    function toUint160(uint256 y) internal pure returns (uint160 z) {
        if ((z = uint160(y)) != y) revert SafeCastOverflow();
    }

    /**
     * @notice Cast int256 -> int128; revierte en overflow/underflow.
     * @param y Valor a castear.
     * @return z Valor int128.
     */
    function toInt128(int256 y) internal pure returns (int128 z) {
        if ((z = int128(y)) != y) revert SafeCastOverflow();
    }

    /**
     * @notice Cast uint256 -> int256; revierte si y >= 2**255.
     * @param y Valor a castear.
     * @return z Valor int256.
     */
    function toInt256(uint256 y) internal pure returns (int256 z) {
        if (y >= 2 ** 255) revert SafeCastOverflow();
        z = int256(y);
    }
}
