// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TickMath} from "../../src/libraries/TickMath.sol";
import {CLTestBase} from "../helpers/CLTestBase.sol";

/**
 * @title CLPoolGasTest
 * @notice Fase 7: coste mint / swap / burn / collect (`forge snapshot`).
 * @dev Cada test mide solo la operacion objetivo (prep en setUp).
 */
contract CLPoolGasTest is CLTestBase {
    int24 internal lower;
    int24 internal upper;

    function setUp() public {
        _deployPool(TickMath.getSqrtRatioAtTick(0));
        lower = -SPACING * 10;
        upper = SPACING * 10;

        vm.prank(lp);
        mintRouter.mint(lp, lower, upper, LIQ);

        // Prep para poke/collect: un swap genera fee growth
        vm.prank(trader);
        swapRouter.swapExactInput(trader, true, 1e14, TickMath.getSqrtRatioAtTick(-SPACING * 5));
    }

    /// @notice Mint liquidez in-range adicional.
    function testGas_mint_inRange() public {
        vm.prank(lp);
        mintRouter.mint(lp, lower, upper, LIQ / 10);
    }

    /// @notice Swap exact input zeroForOne (parcial).
    function testGas_swap_exactIn_zeroForOne() public {
        vm.prank(trader);
        swapRouter.swapExactInput(trader, true, 1e14, TickMath.getSqrtRatioAtTick(-SPACING * 8));
    }

    /// @notice Swap exact input oneForZero (parcial).
    function testGas_swap_exactIn_oneForZero() public {
        vm.prank(trader);
        swapRouter.swapExactInput(trader, false, 1e14, TickMath.getSqrtRatioAtTick(SPACING * 5));
    }

    /// @notice Burn liquidez (sin collect).
    function testGas_burn() public {
        vm.prank(lp);
        pool.burn(lower, upper, LIQ / 10);
    }

    /// @notice Poke fees (burn 0) tras swap en setUp.
    function testGas_burn_poke() public {
        vm.prank(lp);
        pool.burn(lower, upper, 0);
    }

    /// @notice Collect tras burn parcial.
    function testGas_collect() public {
        vm.startPrank(lp);
        pool.burn(lower, upper, LIQ / 10);
        pool.collect(lp, lower, upper, type(uint128).max, type(uint128).max);
        vm.stopPrank();
    }
}
