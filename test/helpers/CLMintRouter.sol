// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICLMintCallback} from "../../src/interfaces/ICLMintCallback.sol";
import {ICLPool} from "../../src/interfaces/ICLPool.sol";

/**
 * @title CLMintRouter
 * @notice Helper de test: llama mint y paga tokens en el callback.
 */
contract CLMintRouter is ICLMintCallback {
    using SafeERC20 for IERC20;

    ICLPool public immutable pool;

    constructor(ICLPool pool_) {
        pool = pool_;
    }

    /**
     * @notice Mint via callback de pago.
     * @param recipient Dueno de la posicion.
     * @param tickLower Tick inferior.
     * @param tickUpper Tick superior.
     * @param amount Liquidez L.
     * @return amount0 Token0 pagado.
     * @return amount1 Token1 pagado.
     */
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        return pool.mint(recipient, tickLower, tickUpper, amount, abi.encode(msg.sender));
    }

    /// @inheritdoc ICLMintCallback
    function clMintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        require(msg.sender == address(pool), "not pool");
        address payer = abi.decode(data, (address));
        if (amount0Owed > 0) {
            IERC20(pool.token0()).safeTransferFrom(payer, address(pool), amount0Owed);
        }
        if (amount1Owed > 0) {
            IERC20(pool.token1()).safeTransferFrom(payer, address(pool), amount1Owed);
        }
    }
}
