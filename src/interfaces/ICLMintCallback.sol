// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ICLMintCallback
 * @notice Callback tras mint: el caller debe pagar amount0/amount1 al pool.
 */
interface ICLMintCallback {
    /**
     * @notice Llamado por el pool tras actualizar la posicion; pagar tokens debidos.
     * @param amount0Owed Token0 debido al pool.
     * @param amount1Owed Token1 debido al pool.
     * @param data Datos opacos pasados desde mint.
     */
    function clMintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external;
}
