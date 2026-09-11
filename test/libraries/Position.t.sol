// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {FixedPoint128} from "../../src/libraries/FixedPoint128.sol";
import {Position} from "../../src/libraries/Position.sol";
import {NoLiquidityPosition} from "../../src/errors/CLErrors.sol";

/**
 * @title PositionHarness
 * @notice Expone Position sobre storage para tests.
 */
contract PositionHarness {
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    mapping(bytes32 => Position.Info) public positions;

    function get(address owner, int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position.Info storage info = positions.get(owner, tickLower, tickUpper);
        return (
            info.liquidity,
            info.feeGrowthInside0LastX128,
            info.feeGrowthInside1LastX128,
            info.tokensOwed0,
            info.tokensOwed1
        );
    }

    function update(address owner, int24 tickLower, int24 tickUpper, int128 liquidityDelta, uint256 fg0, uint256 fg1)
        external
    {
        positions.get(owner, tickLower, tickUpper).update(liquidityDelta, fg0, fg1);
    }
}

/**
 * @title PositionTest
 * @notice Unit tests de Position.update y fees owed (Fase 3).
 */
contract PositionTest is Test {
    PositionHarness internal harness;
    address internal constant OWNER = address(0xBEEF);
    int24 internal constant LOWER = -60;
    int24 internal constant UPPER = 60;

    function setUp() public {
        harness = new PositionHarness();
    }

    function test_Update_Mint_SetsLiquidity() public {
        harness.update(OWNER, LOWER, UPPER, 1_000, 0, 0);
        (uint128 liq,,,,) = harness.get(OWNER, LOWER, UPPER);
        assertEq(liq, 1_000);
    }

    function test_Update_Burn_ReducesLiquidity() public {
        harness.update(OWNER, LOWER, UPPER, 1_000, 0, 0);
        harness.update(OWNER, LOWER, UPPER, -400, 0, 0);
        (uint128 liq,,,,) = harness.get(OWNER, LOWER, UPPER);
        assertEq(liq, 600);
    }

    function test_Update_CreditsFeesOwed() public {
        harness.update(OWNER, LOWER, UPPER, 1_000, 0, 0);

        // feeGrowthInside increases by Q128 ⇒ 1 unit fee per liquidity
        uint256 fg0 = FixedPoint128.Q128; // delta = Q128 → tokensOwed0 = 1000 * Q128 / Q128 = 1000
        uint256 fg1 = FixedPoint128.Q128 * 2;
        harness.update(OWNER, LOWER, UPPER, 0, fg0, fg1); // poke

        (uint128 liq,,, uint128 owed0, uint128 owed1) = harness.get(OWNER, LOWER, UPPER);
        assertEq(liq, 1_000);
        assertEq(owed0, 1_000);
        assertEq(owed1, 2_000);
    }

    function test_Update_Poke_RevertsZeroLiquidity() public {
        vm.expectRevert(NoLiquidityPosition.selector);
        harness.update(OWNER, LOWER, UPPER, 0, 1, 1);
    }

    function test_Update_DifferentOwners_Isolated() public {
        address other = address(0xCAFE);
        harness.update(OWNER, LOWER, UPPER, 100, 0, 0);
        harness.update(other, LOWER, UPPER, 200, 0, 0);
        (uint128 liqA,,,,) = harness.get(OWNER, LOWER, UPPER);
        (uint128 liqB,,,,) = harness.get(other, LOWER, UPPER);
        assertEq(liqA, 100);
        assertEq(liqB, 200);
    }

    function test_Update_BurnWithFees_CreditsThenReducesL() public {
        harness.update(OWNER, LOWER, UPPER, 500, 0, 0);
        harness.update(OWNER, LOWER, UPPER, -500, FixedPoint128.Q128, 0);
        (uint128 liq,,, uint128 owed0,) = harness.get(OWNER, LOWER, UPPER);
        assertEq(liq, 0);
        assertEq(owed0, 500);
    }
}
