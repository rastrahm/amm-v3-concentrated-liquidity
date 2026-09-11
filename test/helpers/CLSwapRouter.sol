// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICLPool} from "../../src/interfaces/ICLPool.sol";
import {ICLSwapCallback} from "../../src/interfaces/ICLSwapCallback.sol";

/**
 * @title CLSwapRouter
 * @notice Helper de test: llama swap y paga el token de input en el callback.
 */
contract CLSwapRouter is ICLSwapCallback {
    using SafeERC20 for IERC20;

    ICLPool public immutable pool;

    constructor(ICLPool pool_) {
        pool = pool_;
    }

    /**
     * @notice Swap exact input.
     * @param recipient Destinatario del output.
     * @param zeroForOne Direccion del swap.
     * @param amountIn Cantidad de input.
     * @param sqrtPriceLimitX96 Limite de precio.
     * @return amount0 Delta token0.
     * @return amount1 Delta token1.
     */
    function swapExactInput(address recipient, bool zeroForOne, uint256 amountIn, uint160 sqrtPriceLimitX96)
        external
        returns (int256 amount0, int256 amount1)
    {
        return pool.swap(recipient, zeroForOne, int256(amountIn), sqrtPriceLimitX96, abi.encode(msg.sender));
    }

    /// @inheritdoc ICLSwapCallback
    function clSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        require(msg.sender == address(pool), "not pool");
        address payer = abi.decode(data, (address));
        if (amount0Delta > 0) {
            IERC20(pool.token0()).safeTransferFrom(payer, address(pool), uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(pool.token1()).safeTransferFrom(payer, address(pool), uint256(amount1Delta));
        }
    }
}
