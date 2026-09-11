// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TickMath} from "../src/libraries/TickMath.sol";
import {CLTestBase} from "./helpers/CLTestBase.sol";

/**
 * @title CLPoolE2ETest
 * @notice Flujo e2e mint → swap → burn → collect via factory (Fase 6).
 */
contract CLPoolE2ETest is CLTestBase {
    int24 internal lower;
    int24 internal upper;

    function setUp() public {
        _deployPool(TickMath.getSqrtRatioAtTick(0));
        lower = -SPACING * 10;
        upper = SPACING * 10;
    }

    function test_E2E_MintSwapBurnCollect() public {
        vm.prank(lp);
        (uint256 minted0, uint256 minted1) = mintRouter.mint(lp, lower, upper, LIQ);
        assertGt(minted0, 0);
        assertGt(minted1, 0);
        assertEq(pool.liquidity(), LIQ);

        uint256 trader1Before = token1.balanceOf(trader);
        vm.prank(trader);
        (int256 d0, int256 d1) =
            swapRouter.swapExactInput(trader, true, 1e12, TickMath.getSqrtRatioAtTick(-SPACING * 5));
        assertGt(d0, 0);
        assertLt(d1, 0);
        assertEq(token1.balanceOf(trader), trader1Before + uint256(-d1));
        assertGt(pool.feeGrowthGlobal0X128(), 0);
        assertGt(pool.liquidity(), 0); // swap parcial: L sigue activa

        vm.startPrank(lp);
        (uint256 burned0, uint256 burned1) = pool.burn(lower, upper, LIQ);
        // Tras el swap la composicion cambia: no exigimos burned_i <= minted_i por token
        assertTrue(burned0 > 0 || burned1 > 0);
        assertEq(pool.liquidity(), 0);

        uint256 lp0Before = token0.balanceOf(lp);
        uint256 lp1Before = token1.balanceOf(lp);
        (uint128 c0, uint128 c1) = pool.collect(lp, lower, upper, type(uint128).max, type(uint128).max);
        vm.stopPrank();

        // collect = principal quemado + fees acreditados en el burn
        assertGe(c0, burned0);
        assertGe(c1, burned1);
        assertEq(token0.balanceOf(lp), lp0Before + c0);
        assertEq(token1.balanceOf(lp), lp1Before + c1);

        (uint128 posLiq,,, uint128 owed0, uint128 owed1) = pool.getPosition(lp, lower, upper);
        assertEq(posLiq, 0);
        assertEq(owed0, 0);
        assertEq(owed1, 0);
    }
}
