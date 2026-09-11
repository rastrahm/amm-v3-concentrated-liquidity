// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CLPool} from "../src/CLPool.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {PriceTargetExceeded, ZeroLiquidity} from "../src/errors/CLErrors.sol";
import {CLMintRouter} from "./helpers/CLMintRouter.sol";
import {CLSwapRouter} from "./helpers/CLSwapRouter.sol";

/**
 * @title CLPoolSwapTest
 * @notice Unit tests de swap multi-tick y fee growth (Fase 5).
 */
contract CLPoolSwapTest is Test {
    CLPool internal pool;
    MockERC20 internal token0;
    MockERC20 internal token1;
    CLMintRouter internal mintRouter;
    CLSwapRouter internal swapRouter;

    address internal lp = address(0xA11CE);
    address internal trader = address(0xB0B);

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
        pool.initialize(TickMath.getSqrtRatioAtTick(0));

        mintRouter = new CLMintRouter(pool);
        swapRouter = new CLSwapRouter(pool);

        lower = -SPACING * 20; // -1200
        upper = SPACING * 20; // 1200

        token0.mint(lp, type(uint128).max);
        token1.mint(lp, type(uint128).max);
        token0.mint(trader, type(uint128).max);
        token1.mint(trader, type(uint128).max);

        vm.startPrank(lp);
        token0.approve(address(mintRouter), type(uint256).max);
        token1.approve(address(mintRouter), type(uint256).max);
        mintRouter.mint(lp, lower, upper, LIQ);
        vm.stopPrank();

        vm.startPrank(trader);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function test_Swap_ExactIn_ZeroForOne_MovesPriceDown() public {
        (uint160 sqrtBefore, int24 tickBefore,) = pool.slot0();

        vm.prank(trader);
        (int256 amount0, int256 amount1) =
            swapRouter.swapExactInput(trader, true, 1e15, TickMath.MIN_SQRT_RATIO + 1);

        assertGt(amount0, 0); // pool recibe token0
        assertLt(amount1, 0); // pool envia token1
        (uint160 sqrtAfter, int24 tickAfter,) = pool.slot0();
        assertLt(sqrtAfter, sqrtBefore);
        assertLe(tickAfter, tickBefore);
    }

    function test_Swap_ExactIn_OneForZero_MovesPriceUp() public {
        (uint160 sqrtBefore,,) = pool.slot0();

        vm.prank(trader);
        (int256 amount0, int256 amount1) =
            swapRouter.swapExactInput(trader, false, 1e15, TickMath.MAX_SQRT_RATIO - 1);

        assertLt(amount0, 0);
        assertGt(amount1, 0);
        (uint160 sqrtAfter,,) = pool.slot0();
        assertGt(sqrtAfter, sqrtBefore);
    }

    function test_Swap_IncreasesFeeGrowthGlobal0() public {
        uint256 fg0Before = pool.feeGrowthGlobal0X128();
        assertEq(fg0Before, 0);

        vm.prank(trader);
        swapRouter.swapExactInput(trader, true, 1e16, TickMath.MIN_SQRT_RATIO + 1);

        assertGt(pool.feeGrowthGlobal0X128(), 0);
        assertEq(pool.feeGrowthGlobal1X128(), 0);
    }

    function test_Swap_LpCollectsFeesAfterPoke() public {
        vm.prank(trader);
        swapRouter.swapExactInput(trader, true, 1e17, TickMath.MIN_SQRT_RATIO + 1);

        vm.startPrank(lp);
        pool.burn(lower, upper, 0); // poke fees
        (,,, uint128 owed0, uint128 owed1) = pool.getPosition(lp, lower, upper);
        assertGt(owed0, 0);
        assertEq(owed1, 0);

        uint256 bal0Before = token0.balanceOf(lp);
        (uint128 c0,) = pool.collect(lp, lower, upper, type(uint128).max, type(uint128).max);
        vm.stopPrank();

        assertEq(c0, owed0);
        assertEq(token0.balanceOf(lp), bal0Before + c0);
    }

    function test_Swap_CrossesInitializedTick_AdjustsLiquidity() public {
        // Rango estrecho adicional que se cruzara al bajar precio
        int24 midLower = -SPACING * 5; // -300
        int24 midUpper = SPACING * 5; // 300

        vm.startPrank(lp);
        mintRouter.mint(lp, midLower, midUpper, LIQ);
        vm.stopPrank();

        uint128 liqBefore = pool.liquidity();
        assertEq(liqBefore, LIQ * 2); // ambas posiciones in-range

        // Limite entre midLower y el lower wide (-1200) para cruzar solo -300
        uint160 limit = TickMath.getSqrtRatioAtTick(-SPACING * 10); // tick -600
        vm.prank(trader);
        swapRouter.swapExactInput(trader, true, type(uint128).max / 4, limit);

        (, int24 tickAfter,) = pool.slot0();
        assertLt(tickAfter, midLower);
        assertGe(tickAfter, lower);

        // Al cruzar midLower hacia la izquierda, se resta liquidez de esa posicion
        assertEq(pool.liquidity(), LIQ); // solo queda el rango wide
    }

    function test_Swap_RevertsInvalidPriceLimit() public {
        (uint160 sqrtP,,) = pool.slot0();
        vm.prank(trader);
        vm.expectRevert(PriceTargetExceeded.selector);
        // limit >= current para zeroForOne es invalido
        swapRouter.swapExactInput(trader, true, 1e15, sqrtP);
    }

    function test_Swap_RevertsZeroAmount() public {
        vm.prank(trader);
        vm.expectRevert(ZeroLiquidity.selector);
        pool.swap(trader, true, 0, TickMath.MIN_SQRT_RATIO + 1, "");
    }

    function test_Swap_RespectsPriceLimit() public {
        uint160 limit = TickMath.getSqrtRatioAtTick(-SPACING); // -60
        vm.prank(trader);
        swapRouter.swapExactInput(trader, true, type(uint64).max, limit);

        (uint160 sqrtAfter,,) = pool.slot0();
        assertGe(sqrtAfter, limit);
    }

    function test_MintTest_BurnZero_NoLongerReverts() public {
        // burn(0) es poke — no debe revertir ZeroLiquidity
        vm.prank(lp);
        pool.burn(lower, upper, 0);
    }
}
