// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

/**
 * @title FixedPoint128
 * @notice Constante Q128 para fee growth por unidad de liquidez.
 * @dev Adaptado de Uniswap v3-core.
 */
library FixedPoint128 {
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
}
