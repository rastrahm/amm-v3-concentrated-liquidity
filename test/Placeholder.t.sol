// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Placeholder} from "../src/Placeholder.sol";

/**
 * @title PlaceholderTest
 * @notice Smoke test de Fase 0: forge-std + remappings OZ + compile.
 */
contract PlaceholderTest is Test {
    Placeholder internal placeholder;

    function setUp() public {
        placeholder = new Placeholder();
    }

    function test_Ping() public view {
        assertTrue(placeholder.ping());
    }

    function test_ModuleName() public view {
        assertEq(placeholder.MODULE(), "14-amm-v3-concentrated-liquidity");
    }

    /// @dev Compila solo si el remapping `@openzeppelin/contracts/` resuelve.
    function test_OpenZeppelinRemapping() public pure {
        assertEq(type(IERC20).interfaceId, bytes4(0x36372b07));
    }
}
