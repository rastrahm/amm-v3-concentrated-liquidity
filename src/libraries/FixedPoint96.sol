// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

/**
 * @title FixedPoint96
 * @notice Constantes Q64.96 usadas por SqrtPriceMath.
 * @dev Adaptado de Uniswap v3-core.
 */
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}
