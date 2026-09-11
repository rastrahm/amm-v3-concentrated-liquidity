// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title Placeholder
 * @notice Stub de Fase 0 para validar compilacion y remappings.
 * @dev Se elimina al implementar las libs/contratos reales (Fase 1+).
 */
contract Placeholder {
    /// @notice Identificador del modulo para smoke tests.
    string public constant MODULE = "14-amm-v3-concentrated-liquidity";

    /**
     * @notice Retorna true si el scaffold esta vivo.
     * @return ok Siempre true en Fase 0.
     */
    function ping() external pure returns (bool ok) {
        return true;
    }
}
