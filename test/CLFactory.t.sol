// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CLFactory} from "../src/CLFactory.sol";
import {CLPool} from "../src/CLPool.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {
    IdenticalAddresses,
    InvalidFee,
    PoolAlreadyExists,
    Unauthorized,
    ZeroAddress
} from "../src/errors/CLErrors.sol";

/**
 * @title CLFactoryTest
 * @notice Unit tests de createPool / fee tiers / ownership (Fase 6).
 */
contract CLFactoryTest is Test {
    CLFactory internal factory;
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;

    function setUp() public {
        factory = new CLFactory();
        tokenA = new MockERC20("A", "A");
        tokenB = new MockERC20("B", "B");
    }

    function test_DefaultFeeTiers() public view {
        assertEq(factory.feeAmountTickSpacing(500), 10);
        assertEq(factory.feeAmountTickSpacing(3000), 60);
        assertEq(factory.feeAmountTickSpacing(10000), 200);
        assertEq(factory.owner(), address(this));
    }

    function test_CreatePool_OrdersTokensAndStoresBothDirections() public {
        address pool = factory.createPool(address(tokenB), address(tokenA), 3000);
        (address t0, address t1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));

        assertEq(CLPool(pool).token0(), t0);
        assertEq(CLPool(pool).token1(), t1);
        assertEq(CLPool(pool).fee(), 3000);
        assertEq(CLPool(pool).tickSpacing(), 60);
        assertEq(CLPool(pool).factory(), address(factory));
        assertEq(factory.getPool(t0, t1, 3000), pool);
        assertEq(factory.getPool(t1, t0, 3000), pool);
    }

    function test_CreatePool_RevertsIdentical() public {
        vm.expectRevert(IdenticalAddresses.selector);
        factory.createPool(address(tokenA), address(tokenA), 3000);
    }

    function test_CreatePool_RevertsZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        factory.createPool(address(0), address(tokenA), 3000);
    }

    function test_CreatePool_RevertsInvalidFee() public {
        vm.expectRevert(InvalidFee.selector);
        factory.createPool(address(tokenA), address(tokenB), 123);
    }

    function test_CreatePool_RevertsAlreadyExists() public {
        factory.createPool(address(tokenA), address(tokenB), 3000);
        vm.expectRevert(PoolAlreadyExists.selector);
        factory.createPool(address(tokenB), address(tokenA), 3000);
    }

    function test_EnableFeeAmount_OnlyOwner() public {
        factory.enableFeeAmount(100, 1);
        assertEq(factory.feeAmountTickSpacing(100), 1);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Unauthorized.selector);
        factory.enableFeeAmount(200, 2);
    }

    function test_SetOwner() public {
        address next = address(0xB0B);
        factory.setOwner(next);
        assertEq(factory.owner(), next);

        vm.expectRevert(Unauthorized.selector);
        factory.setOwner(address(this));
    }
}
