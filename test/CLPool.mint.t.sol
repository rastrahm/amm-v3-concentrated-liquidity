// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CLPool} from "../src/CLPool.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {
    AlreadyInitialized,
    InvalidTickRange,
    TickNotSpaced,
    ZeroLiquidity
} from "../src/errors/CLErrors.sol";
import {CLMintRouter} from "./helpers/CLMintRouter.sol";

/**
 * @title CLPoolMintTest
 * @notice Unit tests mint / burn / collect (Fase 4).
 */
contract CLPoolMintTest is Test {
    CLPool internal pool;
    MockERC20 internal token0;
    MockERC20 internal token1;
    CLMintRouter internal router;

    address internal lp = address(0xA11CE);

    int24 internal constant SPACING = 60;
    uint24 internal constant FEE = 3000;
    uint128 internal constant LIQ = 1_000_000_000_000_000; // 1e15

    int24 internal lower;
    int24 internal upper;

    function setUp() public {
        MockERC20 a = new MockERC20("A", "A");
        MockERC20 b = new MockERC20("B", "B");
        if (address(a) < address(b)) {
            token0 = a;
            token1 = b;
        } else {
            token0 = b;
            token1 = a;
        }

        pool = new CLPool(address(this), address(token0), address(token1), FEE, SPACING);
        pool.initialize(TickMath.getSqrtRatioAtTick(0)); // price = 1

        router = new CLMintRouter(pool);

        lower = -SPACING * 10; // -600
        upper = SPACING * 10; // 600

        token0.mint(lp, type(uint128).max);
        token1.mint(lp, type(uint128).max);
        vm.startPrank(lp);
        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function test_Initialize_SetsSlot0() public view {
        (uint160 sqrtP, int24 tick, bool unlocked) = pool.slot0();
        assertEq(sqrtP, TickMath.getSqrtRatioAtTick(0));
        assertEq(tick, 0);
        assertTrue(unlocked);
    }

    function test_Initialize_RevertsIfTwice() public {
        vm.expectRevert(AlreadyInitialized.selector);
        pool.initialize(TickMath.getSqrtRatioAtTick(1));
    }

    function test_Mint_InsideRange_PaysBothTokens() public {
        vm.prank(lp);
        (uint256 amount0, uint256 amount1) = router.mint(lp, lower, upper, LIQ);

        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertEq(token0.balanceOf(address(pool)), amount0);
        assertEq(token1.balanceOf(address(pool)), amount1);
        assertEq(pool.liquidity(), LIQ);

        (uint128 posLiq,,,,) = pool.getPosition(lp, lower, upper);
        assertEq(posLiq, LIQ);
    }

    function test_Mint_BelowRange_OnlyToken0() public {
        // range entirely above current tick 0
        int24 lo = SPACING * 20;
        int24 hi = SPACING * 40;

        vm.prank(lp);
        (uint256 amount0, uint256 amount1) = router.mint(lp, lo, hi, LIQ);

        assertGt(amount0, 0);
        assertEq(amount1, 0);
        assertEq(pool.liquidity(), 0); // out of range → L global unchanged
    }

    function test_Mint_AboveRange_OnlyToken1() public {
        int24 lo = -SPACING * 40;
        int24 hi = -SPACING * 20;

        vm.prank(lp);
        (uint256 amount0, uint256 amount1) = router.mint(lp, lo, hi, LIQ);

        assertEq(amount0, 0);
        assertGt(amount1, 0);
        assertEq(pool.liquidity(), 0);
    }

    function test_Mint_RevertsZeroLiquidity() public {
        vm.prank(lp);
        vm.expectRevert(ZeroLiquidity.selector);
        router.mint(lp, lower, upper, 0);
    }

    function test_Mint_RevertsInvalidTickRange() public {
        vm.prank(lp);
        vm.expectRevert(InvalidTickRange.selector);
        router.mint(lp, upper, lower, LIQ);
    }

    function test_Mint_RevertsTickNotSpaced() public {
        vm.prank(lp);
        vm.expectRevert(TickNotSpaced.selector);
        router.mint(lp, -61, 60, LIQ);
    }

    function test_Burn_ThenCollect_ReturnsTokens() public {
        vm.startPrank(lp);
        (uint256 minted0, uint256 minted1) = router.mint(lp, lower, upper, LIQ);

        (uint256 burned0, uint256 burned1) = pool.burn(lower, upper, LIQ);
        assertGt(burned0, 0);
        assertGt(burned1, 0);
        // burn rounds down vs mint up → burned <= minted
        assertLe(burned0, minted0);
        assertLe(burned1, minted1);

        uint256 bal0Before = token0.balanceOf(lp);
        uint256 bal1Before = token1.balanceOf(lp);

        (uint128 c0, uint128 c1) = pool.collect(lp, lower, upper, type(uint128).max, type(uint128).max);
        vm.stopPrank();

        assertEq(c0, burned0);
        assertEq(c1, burned1);
        assertEq(token0.balanceOf(lp), bal0Before + c0);
        assertEq(token1.balanceOf(lp), bal1Before + c1);
        assertEq(pool.liquidity(), 0);

        (uint128 posLiq,,,,) = pool.getPosition(lp, lower, upper);
        assertEq(posLiq, 0);
    }

    function test_Burn_Partial_KeepsRemainingLiquidity() public {
        vm.startPrank(lp);
        router.mint(lp, lower, upper, LIQ);
        pool.burn(lower, upper, LIQ / 2);
        vm.stopPrank();

        assertEq(pool.liquidity(), LIQ / 2);
        (uint128 posLiq,,,,) = pool.getPosition(lp, lower, upper);
        assertEq(posLiq, LIQ / 2);
    }

    function test_Burn_Zero_IsPoke() public {
        vm.startPrank(lp);
        router.mint(lp, lower, upper, LIQ);
        // burn(0) acredita fees (0 si no hubo swaps) sin cambiar L
        pool.burn(lower, upper, 0);
        vm.stopPrank();
        assertEq(pool.liquidity(), LIQ);
    }

    function test_Mint_RoundUp_Burn_RoundDown_FavorsPool() public {
        vm.startPrank(lp);
        (uint256 in0, uint256 in1) = router.mint(lp, lower, upper, LIQ);
        (uint256 out0, uint256 out1) = pool.burn(lower, upper, LIQ);
        vm.stopPrank();

        // pool keeps dust from rounding
        assertGe(in0, out0);
        assertGe(in1, out1);
        assertEq(token0.balanceOf(address(pool)), in0); // still in pool until collect
        // after burn, tokens owed but still in pool balance
        assertEq(token0.balanceOf(address(pool)), in0);
        assertGe(in0 - out0 + in1 - out1, 0);
    }
}
