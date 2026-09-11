// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {LiquidityMath} from "../../src/libraries/LiquidityMath.sol";
import {LiquidityOverflow, LiquidityUnderflow} from "../../src/errors/CLErrors.sol";

/**
 * @title LiquidityMathTest
 * @notice Unit + fuzz de addDelta (Fase 2).
 */
contract LiquidityMathTest is Test {
    function test_AddDelta_Add() public pure {
        assertEq(LiquidityMath.addDelta(1000, 500), 1500);
    }

    function test_AddDelta_Sub() public pure {
        assertEq(LiquidityMath.addDelta(1000, -400), 600);
    }

    function test_AddDelta_ZeroDelta() public pure {
        assertEq(LiquidityMath.addDelta(42, 0), 42);
    }

    function test_AddDelta_RevertsUnderflow() public {
        vm.expectRevert(LiquidityUnderflow.selector);
        this.addDeltaExternal(100, -101);
    }

    function test_AddDelta_RevertsOverflow() public {
        vm.expectRevert(LiquidityOverflow.selector);
        this.addDeltaExternal(type(uint128).max, 1);
    }

    function testFuzz_AddDelta_RoundTrip(uint128 x, uint128 delta) public pure {
        uint128 maxDelta = type(uint128).max - x;
        uint128 maxSigned = uint128(uint256(int256(type(int128).max)));
        if (maxDelta > maxSigned) maxDelta = maxSigned;
        delta = uint128(bound(delta, 0, maxDelta));
        uint128 z = LiquidityMath.addDelta(x, int128(delta));
        assertEq(LiquidityMath.addDelta(z, -int128(delta)), x);
    }

    function addDeltaExternal(uint128 x, int128 y) external pure returns (uint128) {
        return LiquidityMath.addDelta(x, y);
    }
}
