// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TickMath} from "../../src/libraries/TickMath.sol";
import {CLTestBase} from "../helpers/CLTestBase.sol";

/**
 * @title CLPoolFuzzTest
 * @notice Fuzz de mint/swap/burn y limites de tick (Fase 6).
 */
contract CLPoolFuzzTest is CLTestBase {
    int24 internal lower;
    int24 internal upper;

    function setUp() public {
        _deployPool(TickMath.getSqrtRatioAtTick(0));
        lower = -SPACING * 50;
        upper = SPACING * 50;

        vm.prank(lp);
        mintRouter.mint(lp, lower, upper, LIQ);
    }

    function testFuzz_SwapExactIn_ZeroForOne_OutputPositive(uint128 amountIn) public {
        amountIn = uint128(bound(amountIn, 1e12, 1e18));
        uint256 bal1Before = token1.balanceOf(trader);

        vm.prank(trader);
        (, int256 amount1) =
            swapRouter.swapExactInput(trader, true, amountIn, TickMath.MIN_SQRT_RATIO + 1);

        assertLt(amount1, 0);
        assertEq(token1.balanceOf(trader), bal1Before + uint256(-amount1));
    }

    function testFuzz_SwapExactIn_OneForZero_OutputPositive(uint128 amountIn) public {
        amountIn = uint128(bound(amountIn, 1e12, 1e18));
        uint256 bal0Before = token0.balanceOf(trader);

        vm.prank(trader);
        (int256 amount0,) =
            swapRouter.swapExactInput(trader, false, amountIn, TickMath.MAX_SQRT_RATIO - 1);

        assertLt(amount0, 0);
        assertEq(token0.balanceOf(trader), bal0Before + uint256(-amount0));
    }

    function testFuzz_MintBurn_RoundTrip_FavorsPool(uint128 liquidityDelta) public {
        liquidityDelta = uint128(bound(liquidityDelta, 1e10, LIQ / 10));
        int24 lo = -SPACING * 5;
        int24 hi = SPACING * 5;

        vm.startPrank(lp);
        (uint256 in0, uint256 in1) = mintRouter.mint(lp, lo, hi, liquidityDelta);
        (uint256 out0, uint256 out1) = pool.burn(lo, hi, liquidityDelta);
        vm.stopPrank();

        assertGe(in0, out0);
        assertGe(in1, out1);
    }

    function testFuzz_CreatePool_UniquePerFee(uint24 feeKey) public {
        feeKey = uint24(bound(feeKey, 1, 999_999));
        if (feeKey == FEE) return; // pool ya existe para FEE en setUp
        if (factory.feeAmountTickSpacing(feeKey) == 0) {
            factory.enableFeeAmount(feeKey, SPACING);
        }

        address p1 = factory.createPool(address(token0), address(token1), feeKey);
        assertTrue(p1 != address(0));
        assertEq(factory.getPool(address(token0), address(token1), feeKey), p1);
    }

    function testFuzz_TickSpacingAligned_MintSucceeds(int24 width) public {
        width = int24(bound(width, 1, 100));
        int24 lo = -width * SPACING;
        int24 hi = width * SPACING;

        if (lo < TickMath.MIN_TICK) lo = (TickMath.MIN_TICK / SPACING) * SPACING;
        if (hi > TickMath.MAX_TICK) hi = (TickMath.MAX_TICK / SPACING) * SPACING;
        if (lo >= hi) return;

        vm.prank(lp);
        (uint256 a0, uint256 a1) = mintRouter.mint(lp, lo, hi, 1e12);
        assertTrue(a0 > 0 || a1 > 0);
    }
}
