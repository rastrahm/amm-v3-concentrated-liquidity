// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TickMath} from "../../src/libraries/TickMath.sol";

/**
 * @title TickMathFuzzTest
 * @notice Fuzz de limites MIN/MAX tick y round-trip tick -> sqrt -> tick (Fase 1).
 */
contract TickMathFuzzTest is Test {
    function testFuzz_RoundTrip_TickToSqrtToTick(int24 tick) public pure {
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        uint160 sqrtP = TickMath.getSqrtRatioAtTick(tick);
        assertEq(TickMath.getTickAtSqrtRatio(sqrtP), tick);
    }

    function testFuzz_GetTickAtSqrtRatio_Invariant(uint160 sqrtPriceX96) public pure {
        sqrtPriceX96 = uint160(bound(sqrtPriceX96, TickMath.MIN_SQRT_RATIO, TickMath.MAX_SQRT_RATIO - 1));
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        assertGe(tick, TickMath.MIN_TICK);
        assertLe(tick, TickMath.MAX_TICK - 1);

        // Definition: greatest tick such that ratio(tick) <= sqrtPrice
        assertLe(TickMath.getSqrtRatioAtTick(tick), sqrtPriceX96);
        if (tick < TickMath.MAX_TICK) {
            // next tick's ratio should be > sqrtPrice (unless we're exactly on a boundary handled above)
            uint160 nextRatio = TickMath.getSqrtRatioAtTick(tick + 1);
            assertGt(nextRatio, sqrtPriceX96);
        }
    }

    function testFuzz_SqrtRatio_Monotonic(int24 tickA, int24 tickB) public pure {
        tickA = int24(bound(tickA, TickMath.MIN_TICK, TickMath.MAX_TICK));
        tickB = int24(bound(tickB, TickMath.MIN_TICK, TickMath.MAX_TICK));
        if (tickA > tickB) {
            (tickA, tickB) = (tickB, tickA);
        }
        if (tickA == tickB) return;
        assertLt(TickMath.getSqrtRatioAtTick(tickA), TickMath.getSqrtRatioAtTick(tickB));
    }
}
