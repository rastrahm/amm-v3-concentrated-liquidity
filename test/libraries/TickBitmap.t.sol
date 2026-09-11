// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {TickBitmap} from "../../src/libraries/TickBitmap.sol";
import {TickNotSpaced} from "../../src/errors/CLErrors.sol";

/**
 * @title TickBitmapHarness
 * @notice Expone TickBitmap sobre storage para tests.
 */
contract TickBitmapHarness {
    using TickBitmap for mapping(int16 => uint256);

    mapping(int16 => uint256) public bitmap;

    function flipTick(int24 tick, int24 tickSpacing) external {
        bitmap.flipTick(tick, tickSpacing);
    }

    function nextInitializedTickWithinOneWord(int24 tick, int24 tickSpacing, bool lte)
        external
        view
        returns (int24 next, bool initialized)
    {
        return bitmap.nextInitializedTickWithinOneWord(tick, tickSpacing, lte);
    }

    function isInitialized(int24 tick, int24 tickSpacing) external view returns (bool) {
        (int16 wordPos, uint8 bitPos) = _position(tick / tickSpacing);
        uint256 mask = 1 << bitPos;
        return bitmap[wordPos] & mask != 0;
    }

    function _position(int24 compressed) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(compressed >> 8);
        bitPos = uint8(int8(compressed % 256));
    }
}

/**
 * @title TickBitmapTest
 * @notice Unit tests de flip y nextInitialized (Fase 3).
 */
contract TickBitmapTest is Test {
    TickBitmapHarness internal harness;
    int24 internal constant SPACING = 60;

    function setUp() public {
        harness = new TickBitmapHarness();
    }

    function test_FlipTick_InitializesAndClears() public {
        harness.flipTick(0, SPACING);
        assertTrue(harness.isInitialized(0, SPACING));
        harness.flipTick(0, SPACING);
        assertFalse(harness.isInitialized(0, SPACING));
    }

    function test_FlipTick_RevertsIfNotSpaced() public {
        vm.expectRevert(TickNotSpaced.selector);
        harness.flipTick(1, SPACING);
    }

    function test_NextInitialized_Lte_FindsSameTick() public {
        harness.flipTick(0, SPACING);
        (int24 next, bool initialized) = harness.nextInitializedTickWithinOneWord(0, SPACING, true);
        assertTrue(initialized);
        assertEq(next, 0);
    }

    function test_NextInitialized_Lte_FindsLeft() public {
        // compressed 0 y 3 estan en la misma word (wordPos=0)
        harness.flipTick(0, SPACING);
        harness.flipTick(180, SPACING);
        (int24 next, bool initialized) = harness.nextInitializedTickWithinOneWord(120, SPACING, true);
        assertTrue(initialized);
        assertEq(next, 0);
    }

    function test_NextInitialized_Gt_FindsRight() public {
        harness.flipTick(0, SPACING);
        harness.flipTick(180, SPACING);
        (int24 next, bool initialized) = harness.nextInitializedTickWithinOneWord(0, SPACING, false);
        assertTrue(initialized);
        assertEq(next, 180);
    }

    function test_NextInitialized_EmptyWord_NotInitialized() public view {
        (int24 next, bool initialized) = harness.nextInitializedTickWithinOneWord(0, SPACING, true);
        assertFalse(initialized);
        // empty lte from 0 → leftmost of word at compressed 0 is bit 0 → next = 0
        assertEq(next, 0);
    }

    function test_NextInitialized_NegativeWord_Lte() public {
        // compressed -4 y -3 comparten wordPos=-1
        harness.flipTick(-240, SPACING); // -4
        harness.flipTick(-180, SPACING); // -3
        (int24 next, bool initialized) = harness.nextInitializedTickWithinOneWord(-181, SPACING, true);
        assertTrue(initialized);
        assertEq(next, -240);
    }

    function testFuzz_FlipTwice_Clears(int24 tickIndex) public {
        // compress to spaced ticks within a safe range
        int24 tick = int24(bound(tickIndex, -100, 100)) * SPACING;
        harness.flipTick(tick, SPACING);
        assertTrue(harness.isInitialized(tick, SPACING));
        harness.flipTick(tick, SPACING);
        assertFalse(harness.isInitialized(tick, SPACING));
    }
}
