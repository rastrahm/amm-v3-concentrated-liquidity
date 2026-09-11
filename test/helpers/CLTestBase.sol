// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CLFactory} from "../../src/CLFactory.sol";
import {CLPool} from "../../src/CLPool.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {TickMath} from "../../src/libraries/TickMath.sol";
import {CLMintRouter} from "./CLMintRouter.sol";
import {CLSwapRouter} from "./CLSwapRouter.sol";

/**
 * @title CLTestBase
 * @notice Setup compartido: factory, pool, routers, LP y trader fondeados.
 */
abstract contract CLTestBase is Test {
    CLFactory internal factory;
    CLPool internal pool;
    MockERC20 internal token0;
    MockERC20 internal token1;
    CLMintRouter internal mintRouter;
    CLSwapRouter internal swapRouter;

    address internal lp = address(0xA11CE);
    address internal trader = address(0xB0B);

    int24 internal constant SPACING = 60;
    uint24 internal constant FEE = 3000;
    uint128 internal constant LIQ = 1_000_000_000_000_000;

    function _deployPool(uint160 sqrtPriceX96) internal {
        factory = new CLFactory();
        MockERC20 a = new MockERC20("A", "A");
        MockERC20 b = new MockERC20("B", "B");
        (token0, token1) = address(a) < address(b) ? (a, b) : (b, a);

        address poolAddr = factory.createPool(address(token0), address(token1), FEE);
        pool = CLPool(poolAddr);
        pool.initialize(sqrtPriceX96);

        mintRouter = new CLMintRouter(pool);
        swapRouter = new CLSwapRouter(pool);

        token0.mint(lp, type(uint128).max);
        token1.mint(lp, type(uint128).max);
        token0.mint(trader, type(uint128).max);
        token1.mint(trader, type(uint128).max);

        vm.startPrank(lp);
        token0.approve(address(mintRouter), type(uint256).max);
        token1.approve(address(mintRouter), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(trader);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }
}
