// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {CLFactory} from "../src/CLFactory.sol";
import {CLPool} from "../src/CLPool.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {TickMath} from "../src/libraries/TickMath.sol";

/**
 * @title Deploy
 * @notice Despliega Factory + mocks + pool demo inicializado (Fase 7).
 * @dev Ejemplo Anvil:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 *
 * Env opcionales:
 * - `PRIVATE_KEY` — deployer (default Anvil #0)
 * - `FEE` — fee tier (default 3000)
 * - `INIT_TICK` — tick inicial del precio (default 0)
 */
contract Deploy is Script {
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);
        uint24 fee = uint24(vm.envOr("FEE", uint256(3000)));
        int256 initTick = int256(vm.envOr("INIT_TICK", uint256(0)));

        vm.startBroadcast(pk);

        CLFactory factory = new CLFactory();
        MockERC20 tokenA = new MockERC20("Token A", "TKA");
        MockERC20 tokenB = new MockERC20("Token B", "TKB");

        (address token0, address token1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));

        address poolAddr = factory.createPool(token0, token1, fee);
        CLPool pool = CLPool(poolAddr);

        int24 tick = int24(initTick);
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
        pool.initialize(sqrtPriceX96);

        // Seed balances for demo LP (deployer)
        MockERC20(token0).mint(deployer, 1_000_000 ether);
        MockERC20(token1).mint(deployer, 1_000_000 ether);

        vm.stopBroadcast();

        console2.log("=== AMM v3 Concentrated Liquidity Deploy ===");
        console2.log("Deployer", deployer);
        console2.log("CLFactory", address(factory));
        console2.log("token0", token0);
        console2.log("token1", token1);
        console2.log("CLPool", poolAddr);
        console2.log("fee", uint256(fee));
        console2.log("tickSpacing", int256(pool.tickSpacing()));
        console2.log("initTick", initTick);
        console2.log("sqrtPriceX96", uint256(sqrtPriceX96));
    }
}
