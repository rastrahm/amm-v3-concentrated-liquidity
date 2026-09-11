// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TickMath} from "../src/libraries/TickMath.sol";
import {CLTestBase} from "./helpers/CLTestBase.sol";

/**
 * @title OutOfRangeFeesTest
 * @notice Posiciones fuera del rango activo no acumulan fees de swap (Fase 6).
 */
contract OutOfRangeFeesTest is CLTestBase {
    function setUp() public {
        _deployPool(TickMath.getSqrtRatioAtTick(0));
    }

    function test_OutOfRange_Above_EarnsZeroFees() public {
        // Posicion entirely above current tick 0
        int24 lo = SPACING * 20;
        int24 hi = SPACING * 40;

        vm.prank(lp);
        mintRouter.mint(lp, lo, hi, LIQ);
        assertEq(pool.liquidity(), 0);

        // Swap oneForZero mueve precio arriba — aun asi la posicion out-of-range al inicio
        // no estaba in-range durante el fee accrual si el swap no entra en [lo,hi).
        // Mint tambien una posicion in-range para que haya L y el swap ocurra.
        vm.prank(lp);
        mintRouter.mint(lp, -SPACING * 10, SPACING * 10, LIQ);

        uint256 fg1Before = pool.feeGrowthGlobal1X128();
        vm.prank(trader);
        // Swap pequeno oneForZero: precio sube pero no hasta tick 20*60=1200
        swapRouter.swapExactInput(trader, false, 1e14, TickMath.getSqrtRatioAtTick(SPACING * 5));

        assertGt(pool.feeGrowthGlobal1X128(), fg1Before);

        // Poke out-of-range position → 0 fees
        vm.prank(lp);
        pool.burn(lo, hi, 0);
        (,,, uint128 owed0, uint128 owed1) = pool.getPosition(lp, lo, hi);
        assertEq(owed0, 0);
        assertEq(owed1, 0);
    }

    function test_OutOfRange_Below_EarnsZeroFees() public {
        int24 lo = -SPACING * 40;
        int24 hi = -SPACING * 20;

        vm.prank(lp);
        mintRouter.mint(lp, lo, hi, LIQ);

        vm.prank(lp);
        mintRouter.mint(lp, -SPACING * 10, SPACING * 10, LIQ);

        vm.prank(trader);
        swapRouter.swapExactInput(trader, true, 1e14, TickMath.getSqrtRatioAtTick(-SPACING * 5));

        assertGt(pool.feeGrowthGlobal0X128(), 0);

        vm.prank(lp);
        pool.burn(lo, hi, 0);
        (,,, uint128 owed0, uint128 owed1) = pool.getPosition(lp, lo, hi);
        assertEq(owed0, 0);
        assertEq(owed1, 0);
    }

    function test_InRange_EarnsFees_WhileOutOfRangeDoesNot() public {
        int24 inLo = -SPACING * 10;
        int24 inHi = SPACING * 10;
        int24 outLo = SPACING * 30;
        int24 outHi = SPACING * 50;

        vm.startPrank(lp);
        mintRouter.mint(lp, inLo, inHi, LIQ);
        mintRouter.mint(lp, outLo, outHi, LIQ);
        vm.stopPrank();

        vm.prank(trader);
        swapRouter.swapExactInput(trader, true, 1e16, TickMath.MIN_SQRT_RATIO + 1);

        vm.startPrank(lp);
        pool.burn(inLo, inHi, 0);
        pool.burn(outLo, outHi, 0);
        vm.stopPrank();

        (,,, uint128 inOwed0,) = pool.getPosition(lp, inLo, inHi);
        (,,, uint128 outOwed0, uint128 outOwed1) = pool.getPosition(lp, outLo, outHi);

        assertGt(inOwed0, 0);
        assertEq(outOwed0, 0);
        assertEq(outOwed1, 0);
    }
}
