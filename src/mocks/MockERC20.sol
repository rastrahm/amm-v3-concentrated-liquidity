// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice ERC-20 de prueba con mint para la suite Foundry.
 */
contract MockERC20 is ERC20 {
    /**
     * @notice Despliega un mock con nombre y simbolo.
     * @param name_ Nombre.
     * @param symbol_ Simbolo.
     */
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    /**
     * @notice Acuna tokens a `to` (solo tests/demo).
     * @param to Destinatario.
     * @param amount Cantidad.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
