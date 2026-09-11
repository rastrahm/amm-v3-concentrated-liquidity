// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TickMath} from "../../src/libraries/TickMath.sol";
import {SqrtPriceMath} from "../../src/libraries/SqrtPriceMath.sol";
import {SwapMath} from "../../src/libraries/SwapMath.sol";

/**
 * @title SwapMathTest
 * @notice Unit + fuzz de computeSwapStep (Fase 2).
 */
contract SwapMathTest is Test {
    uint128 internal constant L = 1_000_000_000_000;
    uint24 internal constant FEE_3000 = 3000; // 0.30%

    function test_ExactIn_ZeroForOne_ReachesTarget() public pure {
        uint160 sqrtCurrent = TickMath.getSqrtRatioAtTick(0);
        uint160 sqrtTarget = TickMath.getSqrtRatioAtTick(-100);
        uint256 amountToTarget =
            SqrtPriceMath.getAmount0Delta(sqrtTarget, sqrtCurrent, L, true);
        // Provide enough input (pre-fee) to reach target
        int256 amountRemaining = int256(amountToTarget * 1e6 / (1e6 - FEE_3000) + 1);

        (uint160 sqrtNext, uint256 amountIn, uint256 amountOut, uint256 feeAmount) =
            SwapMath.computeSwapStep(sqrtCurrent, sqrtTarget, L, amountRemaining, FEE_3000);

        assertEq(sqrtNext, sqrtTarget);
        assertGt(amountIn, 0);
        assertGt(amountOut, 0);
        assertGt(feeAmount, 0);
        assertLe(amountIn + feeAmount, uint256(amountRemaining));
    }

    function test_ExactIn_ZeroForOne_PartialStep() public pure {
        uint160 sqrtCurrent = TickMath.getSqrtRatioAtTick(0);
        uint160 sqrtTarget = TickMath.getSqrtRatioAtTick(-10_000);
        int256 amountRemaining = 1_000_000; // small vs full range

        (uint160 sqrtNext, uint256 amountIn, uint256 amountOut, uint256 feeAmount) =
            SwapMath.computeSwapStep(sqrtCurrent, sqrtTarget, L, amountRemaining, FEE_3000);

        assertLt(sqrtNext, sqrtCurrent);
        assertGt(sqrtNext, sqrtTarget); // did not reach far target
        assertEq(amountIn + feeAmount, uint256(amountRemaining));
        assertGt(amountOut, 0);
    }

    function test_ExactIn_OneForZero_IncreasesPrice() public pure {
        uint160 sqrtCurrent = TickMath.getSqrtRatioAtTick(0);
        uint160 sqrtTarget = TickMath.getSqrtRatioAtTick(100);
        int256 amountRemaining = 1e15;

        (uint160 sqrtNext,, uint256 amountOut,) =
            SwapMath.computeSwapStep(sqrtCurrent, sqrtTarget, L, amountRemaining, FEE_3000);

        assertGt(sqrtNext, sqrtCurrent);
        assertGt(amountOut, 0);
    }

    function test_ExactOut_CapsOutput() public pure {
        uint160 sqrtCurrent = TickMath.getSqrtRatioAtTick(0);
        uint160 sqrtTarget = TickMath.getSqrtRatioAtTick(-500);
        int256 amountRemaining = -1_000_000; // want 1e6 token1 out

        (uint160 sqrtNext, uint256 amountIn, uint256 amountOut, uint256 feeAmount) =
            SwapMath.computeSwapStep(sqrtCurrent, sqrtTarget, L, amountRemaining, FEE_3000);

        assertEq(amountOut, 1_000_000);
        assertGt(amountIn, 0);
        assertGt(feeAmount, 0);
        assertLe(sqrtNext, sqrtCurrent);
    }

    function test_ZeroFee_ExactIn() public pure {
        uint160 sqrtCurrent = TickMath.getSqrtRatioAtTick(0);
        uint160 sqrtTarget = TickMath.getSqrtRatioAtTick(-50);
        int256 amountRemaining = 1e12;

        (uint160 sqrtNext, uint256 amountIn,, uint256 feeAmount) =
            SwapMath.computeSwapStep(sqrtCurrent, sqrtTarget, L, amountRemaining, 0);

        assertEq(feeAmount, 0);
        assertLt(sqrtNext, sqrtCurrent);
        assertLe(amountIn, uint256(amountRemaining));
    }

    function testFuzz_ExactIn_FeePlusIn_Le_Remaining(uint128 amountInRaw) public pure {
        amountInRaw = uint128(bound(amountInRaw, 1e6, type(uint64).max));
        uint160 sqrtCurrent = TickMath.getSqrtRatioAtTick(0);
        uint160 sqrtTarget = TickMath.getSqrtRatioAtTick(-1000);

        (, uint256 amountIn,, uint256 feeAmount) =
            SwapMath.computeSwapStep(sqrtCurrent, sqrtTarget, L, int256(uint256(amountInRaw)), FEE_3000);

        assertLe(amountIn + feeAmount, uint256(amountInRaw));
    }
}
