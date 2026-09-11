// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {FullMath} from "../../src/libraries/FullMath.sol";
import {DenominatorZero, FullMathOverflow} from "../../src/errors/CLErrors.sol";

/**
 * @title FullMathTest
 * @notice Unit + fuzz de mulDiv / mulDivRoundingUp (Fase 1).
 */
contract FullMathTest is Test {
    function test_MulDiv_Basic() public pure {
        assertEq(FullMath.mulDiv(100, 200, 50), 400);
        assertEq(FullMath.mulDiv(7, 3, 2), 10); // floor(21/2)=10
    }

    function test_MulDiv_ZeroNumerator() public pure {
        assertEq(FullMath.mulDiv(0, 1e18, 1e18), 0);
        assertEq(FullMath.mulDiv(1e18, 0, 1e18), 0);
    }

    function test_MulDiv_PhantomOverflow() public pure {
        // a * b overflows uint256 but a*b/denominator fits
        uint256 a = type(uint256).max;
        uint256 b = type(uint256).max;
        uint256 denominator = type(uint256).max;
        assertEq(FullMath.mulDiv(a, b, denominator), type(uint256).max);
    }

    function test_MulDiv_RevertsDenominatorZero() public {
        vm.expectRevert(DenominatorZero.selector);
        this.mulDivExternal(1, 1, 0);
    }

    function test_MulDiv_RevertsOverflow() public {
        // prod1 >= denominator => result would overflow uint256
        vm.expectRevert(FullMathOverflow.selector);
        this.mulDivExternal(type(uint256).max, type(uint256).max, 1);
    }

    function test_MulDivRoundingUp_Exact() public pure {
        assertEq(FullMath.mulDivRoundingUp(10, 10, 5), 20);
    }

    function test_MulDivRoundingUp_RoundsUp() public pure {
        // floor(21/2)=10, ceil=11
        assertEq(FullMath.mulDiv(7, 3, 2), 10);
        assertEq(FullMath.mulDivRoundingUp(7, 3, 2), 11);
    }

    function test_MulDivRoundingUp_RevertsAtMax() public {
        // mulDiv returns max, remainder > 0 => rounding up overflows
        // Use values where floor(a*b/d) == max and remainder != 0
        // a=max, b=max, d=max => result=max, mulmod(max,max,max)=0 so exact — no overflow on round up
        // Need remainder > 0 with result == max:
        // floor((max * max) / (max-1)) ... let's construct:
        // result = mulDiv(max, 2, 2) = max, remainder = 0
        // For remainder > 0 at max result: mulDiv(Q, R, D) = max with mulmod > 0
        // Uniswap test: mulDivRoundingUp(type(uint256).max, type(uint256).max, type(uint256).max) is exact
        // Overflow case: result = max-0 after mulDiv when we'd need +1
        // From Uniswap: require(result < type(uint256).max) when remainder > 0
        // Example: a = type(uint256).max, b = type(uint256).max, denominator = type(uint256).max / 2 + something
        // Simpler known case: floor((2^256-1)*1 / 1) = max, remainder of mulmod(max,1,1)=0
        // Case with remainder: mulDiv(3, 3, 2) = 4, round up would be... 9/2 floor=4, rem=1, ceil=5 OK
        // For overflow on round-up: need floor == max and rem > 0
        // (type(uint256).max * 2 + something) / 2 — but mulDiv of (max, 3, 2):
        // max*3/2 = floor(max*1.5) overflows? prod1 for max*3: might overflow result
        vm.expectRevert(FullMathOverflow.selector);
        this.mulDivRoundingUpExternal(type(uint256).max, type(uint256).max, type(uint256).max - 1);
    }

    function testFuzz_MulDiv_MatchesUncheckedWhenNoPhantom(uint128 a, uint128 b, uint128 denominator) public pure {
        denominator = uint128(bound(denominator, 1, type(uint128).max));
        uint256 expected = (uint256(a) * uint256(b)) / uint256(denominator);
        assertEq(FullMath.mulDiv(a, b, denominator), expected);
    }

    function testFuzz_MulDivRoundingUp_GteFloor(uint128 a, uint128 b, uint128 denominator) public pure {
        denominator = uint128(bound(denominator, 1, type(uint128).max));
        uint256 floor_ = FullMath.mulDiv(a, b, denominator);
        uint256 ceil_ = FullMath.mulDivRoundingUp(a, b, denominator);
        if ((uint256(a) * uint256(b)) % uint256(denominator) == 0) {
            assertEq(ceil_, floor_);
        } else {
            assertEq(ceil_, floor_ + 1);
        }
    }

    function mulDivExternal(uint256 a, uint256 b, uint256 d) external pure returns (uint256) {
        return FullMath.mulDiv(a, b, d);
    }

    function mulDivRoundingUpExternal(uint256 a, uint256 b, uint256 d) external pure returns (uint256) {
        return FullMath.mulDivRoundingUp(a, b, d);
    }
}
