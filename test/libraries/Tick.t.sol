// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Tick} from "../../src/libraries/Tick.sol";
import {LiquidityGrossOverflow} from "../../src/errors/CLErrors.sol";

/**
 * @title TickHarness
 * @notice Expone Tick sobre storage para tests.
 */
contract TickHarness {
    using Tick for mapping(int24 => Tick.Info);

    mapping(int24 => Tick.Info) public ticks;

    function update(
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        bool upper,
        uint128 maxLiquidity
    ) external returns (bool flipped) {
        return ticks.update(
            tick, tickCurrent, liquidityDelta, feeGrowthGlobal0X128, feeGrowthGlobal1X128, upper, maxLiquidity
        );
    }

    function cross(int24 tick, uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128)
        external
        returns (int128 liquidityNet)
    {
        return ticks.cross(tick, feeGrowthGlobal0X128, feeGrowthGlobal1X128);
    }

    function clear(int24 tick) external {
        ticks.clear(tick);
    }

    function getFeeGrowthInside(
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) external view returns (uint256, uint256) {
        return ticks.getFeeGrowthInside(tickLower, tickUpper, tickCurrent, feeGrowthGlobal0X128, feeGrowthGlobal1X128);
    }

    function get(int24 tick)
        external
        view
        returns (uint128 liquidityGross, int128 liquidityNet, uint256 fg0, uint256 fg1, bool initialized)
    {
        Tick.Info storage info = ticks[tick];
        return (
            info.liquidityGross, info.liquidityNet, info.feeGrowthOutside0X128, info.feeGrowthOutside1X128, info.initialized
        );
    }
}

/**
 * @title TickTest
 * @notice Unit tests de update / cross / feeGrowthInside (Fase 3).
 */
contract TickTest is Test {
    TickHarness internal harness;
    uint128 internal constant MAX_LIQ = type(uint128).max / 2;

    function setUp() public {
        harness = new TickHarness();
    }

    function test_TickSpacingToMaxLiquidityPerTick_Fee3000() public pure {
        // spacing 60 (0.3% tier)
        uint128 maxLiq = Tick.tickSpacingToMaxLiquidityPerTick(60);
        assertGt(maxLiq, 0);
        assertLt(maxLiq, type(uint128).max);
    }

    function test_Update_Lower_IncreasesLiquidityNet() public {
        bool flipped = harness.update(-60, 0, 1000, 0, 0, false, MAX_LIQ);
        assertTrue(flipped);
        (uint128 gross, int128 net,,, bool init) = harness.get(-60);
        assertEq(gross, 1000);
        assertEq(net, 1000);
        assertTrue(init);
    }

    function test_Update_Upper_DecreasesLiquidityNet() public {
        bool flipped = harness.update(60, 0, 1000, 0, 0, true, MAX_LIQ);
        assertTrue(flipped);
        (, int128 net,,, ) = harness.get(60);
        assertEq(net, -1000);
    }

    function test_Update_FlipOff_WhenGrossZero() public {
        harness.update(0, 0, 500, 0, 0, false, MAX_LIQ);
        bool flipped = harness.update(0, 0, -500, 0, 0, false, MAX_LIQ);
        assertTrue(flipped);
        (uint128 gross,,,,) = harness.get(0);
        assertEq(gross, 0);
    }

    function test_Update_RevertsGrossOverflow() public {
        harness.update(0, 0, int128(uint128(MAX_LIQ)), 0, 0, false, MAX_LIQ);
        vm.expectRevert(LiquidityGrossOverflow.selector);
        harness.update(0, 0, 1, 0, 0, false, MAX_LIQ);
    }

    function test_Update_InitializesFeeGrowthOutside_WhenTickBelowCurrent() public {
        harness.update(-100, 0, 100, 111, 222, false, MAX_LIQ);
        (,, uint256 fg0, uint256 fg1,) = harness.get(-100);
        assertEq(fg0, 111);
        assertEq(fg1, 222);
    }

    function test_Update_DoesNotInitFeeGrowth_WhenTickAboveCurrent() public {
        harness.update(100, 0, 100, 111, 222, true, MAX_LIQ);
        (,, uint256 fg0, uint256 fg1,) = harness.get(100);
        assertEq(fg0, 0);
        assertEq(fg1, 0);
    }

    function test_Cross_FlipsFeeGrowthOutside_ReturnsNet() public {
        harness.update(0, -10, 1000, 0, 0, false, MAX_LIQ);
        int128 net = harness.cross(0, 500, 700);
        assertEq(net, 1000);
        (,, uint256 fg0, uint256 fg1,) = harness.get(0);
        assertEq(fg0, 500);
        assertEq(fg1, 700);

        // cross again inverts relative to new globals
        harness.cross(0, 800, 900);
        (,, fg0, fg1,) = harness.get(0);
        assertEq(fg0, 300); // 800 - 500
        assertEq(fg1, 200); // 900 - 700
    }

    function test_GetFeeGrowthInside_CurrentInsideRange() public {
        // lower below current, upper above; outside starts 0
        harness.update(-60, 0, 1000, 1000, 2000, false, MAX_LIQ);
        harness.update(60, 0, 1000, 1000, 2000, true, MAX_LIQ);

        // After init: lower (tick <= current) got outside = global at init time
        // upper (tick > current) got outside = 0
        // feeGrowthInside = global - below - above
        // below = lower.outside = 1000/2000 (since current >= lower)
        // above = upper.outside = 0 (since current < upper)
        // inside = 1000-1000-0 = 0, 2000-2000-0 = 0 at init globals
        (uint256 inside0, uint256 inside1) = harness.getFeeGrowthInside(-60, 60, 0, 1000, 2000);
        assertEq(inside0, 0);
        assertEq(inside1, 0);

        // After more global growth without crossing: inside increases
        (inside0, inside1) = harness.getFeeGrowthInside(-60, 60, 0, 1500, 2500);
        assertEq(inside0, 500);
        assertEq(inside1, 500);
    }

    function test_GetFeeGrowthInside_CurrentBelowRange_ZeroGrowthInside() public {
        harness.update(60, 0, 1000, 0, 0, false, MAX_LIQ);
        harness.update(120, 0, 1000, 0, 0, true, MAX_LIQ);
        // current=0 < lower=60: growth happens "below" relative to lower → not inside
        // Simulate globals growing while price below range
        (uint256 inside0,) = harness.getFeeGrowthInside(60, 120, 0, 999, 0);
        // below = global - lower.outside = 999 - 0 = 999; above = 0; inside = 999-999-0 = 0
        assertEq(inside0, 0);
    }

    function test_Clear() public {
        harness.update(0, 0, 100, 1, 2, false, MAX_LIQ);
        harness.clear(0);
        (uint128 gross,,,, bool init) = harness.get(0);
        assertEq(gross, 0);
        assertFalse(init);
    }
}
