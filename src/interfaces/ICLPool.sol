// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ICLPool
 * @notice API del pool de liquidez concentrada (mint/burn/collect; swap en Fase 5).
 */
interface ICLPool {
    /// @notice Estado empaquetado del precio activo.
    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        bool unlocked;
    }

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function tickSpacing() external view returns (int24);
    function maxLiquidityPerTick() external view returns (uint128);
    function liquidity() external view returns (uint128);
    function feeGrowthGlobal0X128() external view returns (uint256);
    function feeGrowthGlobal1X128() external view returns (uint256);
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, bool unlocked);

    /**
     * @notice Inicializa el precio del pool (una sola vez).
     * @param sqrtPriceX96 Precio inicial Q64.96.
     */
    function initialize(uint160 sqrtPriceX96) external;

    /**
     * @notice Anade liquidez a una posicion; cobra via callback.
     * @param recipient Dueno de la posicion.
     * @param tickLower Tick inferior (alineado a spacing).
     * @param tickUpper Tick superior (alineado a spacing).
     * @param amount Liquidez a anadir (L).
     * @param data Datos para el callback de pago.
     * @return amount0 Token0 pagado al pool.
     * @return amount1 Token1 pagado al pool.
     */
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Retira liquidez; acredita tokens a tokensOwed (retirar con collect).
     * @param tickLower Tick inferior.
     * @param tickUpper Tick superior.
     * @param amount Liquidez a retirar.
     * @return amount0 Token0 acreditado.
     * @return amount1 Token1 acreditado.
     */
    function burn(int24 tickLower, int24 tickUpper, uint128 amount)
        external
        returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Transfiere tokensOwed de la posicion al recipient.
     * @param recipient Destinatario.
     * @param tickLower Tick inferior.
     * @param tickUpper Tick superior.
     * @param amount0Requested Max token0 a cobrar.
     * @param amount1Requested Max token1 a cobrar.
     * @return amount0 Token0 transferido.
     * @return amount1 Token1 transferido.
     */
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /**
     * @notice Ejecuta un swap zeroForOne o oneForZero (exact in si amountSpecified > 0).
     * @param recipient Destinatario del token de output.
     * @param zeroForOne true = token0 → token1 (precio baja).
     * @param amountSpecified >0 exact input; <0 exact output.
     * @param sqrtPriceLimitX96 Limite de precio Q64.96.
     * @param data Datos para el callback de pago.
     * @return amount0 Delta token0 (+ pool recibe / - pool envia).
     * @return amount1 Delta token1.
     */
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}
