// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TickMath} from "../../src/libraries/TickMath.sol";
import {SqrtPriceMath} from "../../src/libraries/SqrtPriceMath.sol";
import {FullMathOverflow, ZeroSqrtPriceOrLiquidity} from "../../src/errors/CLErrors.sol";

/**
 * @title SqrtPriceMathTest
 * @notice Unit tests de amounts y next price (Fase 2).
 * @dev Vectores RareSkills: L=1e9, ticks ±10 alrededor de 0 => amount ≈ 499851.
 */
contract SqrtPriceMathTest is Test {
    uint128 internal constant L = 1_000_000_000;

    function test_GetAmount0Delta_KnownVector() public pure {
        uint160 sqrtP = TickMath.getSqrtRatioAtTick(0);
        uint160 sqrtUpper = TickMath.getSqrtRatioAtTick(10);
        uint256 amount0 = SqrtPriceMath.getAmount0Delta(sqrtP, sqrtUpper, L, true);
        assertEq(amount0, 499851);
    }

    function test_GetAmount1Delta_KnownVector() public pure {
        uint160 sqrtLower = TickMath.getSqrtRatioAtTick(-10);
        uint160 sqrtP = TickMath.getSqrtRatioAtTick(0);
        uint256 amount1 = SqrtPriceMath.getAmount1Delta(sqrtLower, sqrtP, L, true);
        assertEq(amount1, 499851);
    }

    function test_Amounts_PriceBelowRange_OnlyToken0() public pure {
        // P < Plower < Pupper => position all in token0 for full range amounts from lower to upper
        uint160 sqrtLower = TickMath.getSqrtRatioAtTick(100);
        uint160 sqrtUpper = TickMath.getSqrtRatioAtTick(200);
        uint256 amount0 = SqrtPriceMath.getAmount0Delta(sqrtLower, sqrtUpper, L, true);
        uint256 amount1 = SqrtPriceMath.getAmount1Delta(sqrtLower, sqrtUpper, L, true);
        assertGt(amount0, 0);
        assertGt(amount1, 0); // delta between two prices always both formulas apply to range width
        // For mint when price below range: only amount0 of [lower,upper] is needed (amount1=0 virtual)
        // Here we just verify amount0 for full range is positive and roundUp >= roundDown
        uint256 amount0Down = SqrtPriceMath.getAmount0Delta(sqrtLower, sqrtUpper, L, false);
        assertGe(amount0, amount0Down);
    }

    function test_RoundUp_Ge_RoundDown_Amount0() public pure {
        uint160 a = TickMath.getSqrtRatioAtTick(-50);
        uint160 b = TickMath.getSqrtRatioAtTick(50);
        uint256 up = SqrtPriceMath.getAmount0Delta(a, b, L, true);
        uint256 down = SqrtPriceMath.getAmount0Delta(a, b, L, false);
        assertGe(up, down);
    }

    function test_RoundUp_Ge_RoundDown_Amount1() public pure {
        uint160 a = TickMath.getSqrtRatioAtTick(-50);
        uint160 b = TickMath.getSqrtRatioAtTick(50);
        uint256 up = SqrtPriceMath.getAmount1Delta(a, b, L, true);
        uint256 down = SqrtPriceMath.getAmount1Delta(a, b, L, false);
        assertGe(up, down);
    }

    function test_SignedDelta_MintRoundsUp_BurnRoundsDown() public pure {
        uint160 a = TickMath.getSqrtRatioAtTick(-20);
        uint160 b = TickMath.getSqrtRatioAtTick(20);
        int256 mint0 = SqrtPriceMath.getAmount0Delta(a, b, int128(L));
        int256 burn0 = SqrtPriceMath.getAmount0Delta(a, b, -int128(L));
        assertGt(mint0, 0);
        assertLt(burn0, 0);
        // |mint| >= |burn| (pool-favorable rounding)
        assertGe(uint256(mint0), uint256(-burn0));
    }

    function test_PriceBelow_Inside_Above_Composition() public pure {
        uint160 sqrtLower = TickMath.getSqrtRatioAtTick(-100);
        uint160 sqrtCurrent = TickMath.getSqrtRatioAtTick(0);
        uint160 sqrtUpper = TickMath.getSqrtRatioAtTick(100);

        // Inside range: amount0 from current->upper, amount1 from lower->current
        uint256 amount0Inside = SqrtPriceMath.getAmount0Delta(sqrtCurrent, sqrtUpper, L, true);
        uint256 amount1Inside = SqrtPriceMath.getAmount1Delta(sqrtLower, sqrtCurrent, L, true);
        assertGt(amount0Inside, 0);
        assertGt(amount1Inside, 0);

        // Below range (P <= lower): only token0 for [lower, upper]
        uint256 amount0Below = SqrtPriceMath.getAmount0Delta(sqrtLower, sqrtUpper, L, true);
        assertGt(amount0Below, amount0Inside);

        // Above range (P >= upper): only token1 for [lower, upper]
        uint256 amount1Above = SqrtPriceMath.getAmount1Delta(sqrtLower, sqrtUpper, L, true);
        assertGt(amount1Above, amount1Inside);
    }

    function test_GetNextSqrtPriceFromInput_ZeroForOne_DecreasesPrice() public pure {
        uint160 sqrtP = TickMath.getSqrtRatioAtTick(0);
        uint160 next = SqrtPriceMath.getNextSqrtPriceFromInput(sqrtP, L, 1e6, true);
        assertLt(next, sqrtP);
    }

    function test_GetNextSqrtPriceFromInput_OneForZero_IncreasesPrice() public pure {
        uint160 sqrtP = TickMath.getSqrtRatioAtTick(0);
        uint160 next = SqrtPriceMath.getNextSqrtPriceFromInput(sqrtP, L, 1e6, false);
        assertGt(next, sqrtP);
    }

    function test_GetNextSqrtPriceFromInput_RevertsZeroLiquidity() public {
        vm.expectRevert(ZeroSqrtPriceOrLiquidity.selector);
        this.nextFromInputExternal(TickMath.getSqrtRatioAtTick(0), 0, 1, true);
    }

    function test_GetNextSqrtPriceFromOutput_JustBelowVirtualReserves() public pure {
        // Uniswap vector
        uint160 price = 20282409603651670423947251286016;
        uint128 liquidity = 1024;
        uint256 amountOut = 262143;
        uint160 sqrtQ = SqrtPriceMath.getNextSqrtPriceFromOutput(price, liquidity, amountOut, true);
        assertEq(sqrtQ, 77371252455336267181195264);
    }

    function test_GetNextSqrtPriceFromOutput_RevertsExactVirtualReserves() public {
        uint160 price = 20282409603651670423947251286016;
        uint128 liquidity = 1024;
        uint256 amountOut = 262144;
        vm.expectRevert(FullMathOverflow.selector);
        this.nextFromOutputExternal(price, liquidity, amountOut, true);
    }

    function nextFromInputExternal(uint160 sqrtP, uint128 liq, uint256 amountIn, bool zeroForOne)
        external
        pure
        returns (uint160)
    {
        return SqrtPriceMath.getNextSqrtPriceFromInput(sqrtP, liq, amountIn, zeroForOne);
    }

    function nextFromOutputExternal(uint160 sqrtP, uint128 liq, uint256 amountOut, bool zeroForOne)
        external
        pure
        returns (uint160)
    {
        return SqrtPriceMath.getNextSqrtPriceFromOutput(sqrtP, liq, amountOut, zeroForOne);
    }
}
