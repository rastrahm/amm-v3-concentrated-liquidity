// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TickMath} from "../../src/libraries/TickMath.sol";
import {InvalidSqrtPrice, InvalidTick} from "../../src/errors/CLErrors.sol";

/**
 * @title TickMathTest
 * @notice Unit tests de tick <-> sqrtPriceX96 (Fase 1).
 */
contract TickMathTest is Test {
    uint160 internal constant SQRT_RATIO_AT_TICK_0 = 79228162514264337593543950336; // 1 << 96

    function test_Constants() public pure {
        assertEq(TickMath.MIN_TICK, -887272);
        assertEq(TickMath.MAX_TICK, 887272);
        assertEq(TickMath.MIN_SQRT_RATIO, 4295128739);
        assertEq(TickMath.MAX_SQRT_RATIO, 1461446703485210103287273052203988822378723970342);
    }

    function test_GetSqrtRatioAtTick_Zero() public pure {
        assertEq(TickMath.getSqrtRatioAtTick(0), SQRT_RATIO_AT_TICK_0);
    }

    function test_GetSqrtRatioAtTick_MinMax() public pure {
        assertEq(TickMath.getSqrtRatioAtTick(TickMath.MIN_TICK), TickMath.MIN_SQRT_RATIO);
        assertEq(TickMath.getSqrtRatioAtTick(TickMath.MAX_TICK), TickMath.MAX_SQRT_RATIO);
    }

    function test_GetSqrtRatioAtTick_Symmetric() public pure {
        uint160 pos = TickMath.getSqrtRatioAtTick(50);
        uint160 neg = TickMath.getSqrtRatioAtTick(-50);
        // product of ratios ≈ (1<<96)^2 for opposite ticks (within Q64.96 precision)
        // sqrt(1.0001^50)*sqrt(1.0001^-50) = 1 => pos * neg ≈ (1<<96)^2
        uint256 product = uint256(pos) * uint256(neg);
        uint256 oneSquared = uint256(SQRT_RATIO_AT_TICK_0) * uint256(SQRT_RATIO_AT_TICK_0);
        // Allow tiny relative error from rounding
        assertApproxEqRel(product, oneSquared, 1e12); // 0.0001%
    }

    function test_GetTickAtSqrtRatio_AtTickZeroPrice() public pure {
        assertEq(TickMath.getTickAtSqrtRatio(SQRT_RATIO_AT_TICK_0), 0);
    }

    function test_GetTickAtSqrtRatio_MinSqrt() public pure {
        assertEq(TickMath.getTickAtSqrtRatio(TickMath.MIN_SQRT_RATIO), TickMath.MIN_TICK);
    }

    function test_RoundTrip_MinMaxAndMid() public pure {
        int24[5] memory ticks = [int24(TickMath.MIN_TICK), int24(-1000), int24(0), int24(1000), int24(TickMath.MAX_TICK)];
        for (uint256 i = 0; i < ticks.length; i++) {
            int24 t = ticks[i];
            uint160 sqrtP = TickMath.getSqrtRatioAtTick(t);
            // MAX_TICK maps to MAX_SQRT_RATIO which is exclusive for getTickAtSqrtRatio
            if (t == TickMath.MAX_TICK) {
                // price at MAX_TICK is not a valid input to getTickAtSqrtRatio (< MAX_SQRT_RATIO)
                assertEq(sqrtP, TickMath.MAX_SQRT_RATIO);
                continue;
            }
            assertEq(TickMath.getTickAtSqrtRatio(sqrtP), t);
        }
    }

    function test_GetSqrtRatioAtTick_RevertsAboveMax() public {
        vm.expectRevert(InvalidTick.selector);
        this.getSqrtRatioAtTickExternal(TickMath.MAX_TICK + 1);
    }

    function test_GetSqrtRatioAtTick_RevertsBelowMin() public {
        vm.expectRevert(InvalidTick.selector);
        this.getSqrtRatioAtTickExternal(TickMath.MIN_TICK - 1);
    }

    function test_GetTickAtSqrtRatio_RevertsBelowMin() public {
        vm.expectRevert(InvalidSqrtPrice.selector);
        this.getTickAtSqrtRatioExternal(TickMath.MIN_SQRT_RATIO - 1);
    }

    function test_GetTickAtSqrtRatio_RevertsAtMax() public {
        vm.expectRevert(InvalidSqrtPrice.selector);
        this.getTickAtSqrtRatioExternal(TickMath.MAX_SQRT_RATIO);
    }

    function test_GetTickAtSqrtRatio_JustBelowMax() public pure {
        uint160 justBelow = TickMath.MAX_SQRT_RATIO - 1;
        int24 tick = TickMath.getTickAtSqrtRatio(justBelow);
        assertEq(tick, TickMath.MAX_TICK - 1);
    }

    function getSqrtRatioAtTickExternal(int24 tick) external pure returns (uint160) {
        return TickMath.getSqrtRatioAtTick(tick);
    }

    function getTickAtSqrtRatioExternal(uint160 sqrtPriceX96) external pure returns (int24) {
        return TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }
}
