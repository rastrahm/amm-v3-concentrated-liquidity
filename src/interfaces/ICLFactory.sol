// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ICLFactory
 * @notice Factory de pools CL por (token0, token1, fee).
 */
interface ICLFactory {
    function owner() external view returns (address);
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);

    /**
     * @notice Crea un pool para el par y fee (tokens se ordenan).
     * @param tokenA Primer token.
     * @param tokenB Segundo token.
     * @param fee Fee tier habilitado.
     * @return pool Direccion del nuevo CLPool.
     */
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);

    /**
     * @notice Habilita un fee tier con su tickSpacing (solo owner).
     * @param fee Fee en hundredths of a bip (< 1e6).
     * @param tickSpacing Espaciado (1..16383).
     */
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;

    /**
     * @notice Transfiere ownership.
     * @param owner_ Nuevo owner.
     */
    function setOwner(address owner_) external;
}
