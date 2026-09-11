// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ICLSwapCallback
 * @notice Callback tras swap: el caller debe pagar el token de input al pool.
 */
interface ICLSwapCallback {
    /**
     * @notice Llamado por el pool tras el swap; pagar deltas positivos.
     * @param amount0Delta Delta de token0 para el pool (+ recibe, - envia).
     * @param amount1Delta Delta de token1 para el pool (+ recibe, - envia).
     * @param data Datos opacos pasados desde swap.
     */
    function clSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}
