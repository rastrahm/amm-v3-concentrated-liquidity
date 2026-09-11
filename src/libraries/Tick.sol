// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {LiquidityGrossOverflow} from "../errors/CLErrors.sol";
import {TickMath} from "./TickMath.sol";

/**
 * @title Tick
 * @notice Estado por tick: liquidez bruta/neta y fee growth outside.
 * @dev Adaptado de Uniswap v3-core (v1 sin campos TWAP/oracle).
 */
library Tick {
    /// @notice Datos de un tick inicializado.
    struct Info {
        uint128 liquidityGross;
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        bool initialized;
    }

    /**
     * @notice Maxima liquidez bruta por tick segun spacing.
     * @param tickSpacing Separacion entre ticks usables.
     * @return maxLiquidity Max liquidityGross admitido.
     */
    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128 maxLiquidity) {
        unchecked {
            int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
            int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
            uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
            maxLiquidity = type(uint128).max / numTicks;
        }
    }

    /**
     * @notice Fee growth acumulado dentro de [tickLower, tickUpper).
     * @param self Mapping de ticks.
     * @param tickLower Limite inferior.
     * @param tickUpper Limite superior.
     * @param tickCurrent Tick activo del pool.
     * @param feeGrowthGlobal0X128 Fee growth global token0.
     * @param feeGrowthGlobal1X128 Fee growth global token1.
     * @return feeGrowthInside0X128 Growth inside en token0.
     * @return feeGrowthInside1X128 Growth inside en token1.
     */
    function getFeeGrowthInside(
        mapping(int24 => Info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        unchecked {
            Info storage lower = self[tickLower];
            Info storage upper = self[tickUpper];

            uint256 feeGrowthBelow0X128;
            uint256 feeGrowthBelow1X128;
            if (tickCurrent >= tickLower) {
                feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
                feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
            } else {
                feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
                feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
            }

            uint256 feeGrowthAbove0X128;
            uint256 feeGrowthAbove1X128;
            if (tickCurrent < tickUpper) {
                feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
                feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
            } else {
                feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
                feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
            }

            feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
            feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
        }
    }

    /**
     * @notice Actualiza liquidez de un tick; retorna si se flippeo initialized.
     * @param self Mapping de ticks.
     * @param tick Tick a actualizar.
     * @param tickCurrent Tick actual del pool.
     * @param liquidityDelta Delta de liquidez de la posicion.
     * @param feeGrowthGlobal0X128 Fee growth global token0.
     * @param feeGrowthGlobal1X128 Fee growth global token1.
     * @param upper true si es tick upper de la posicion.
     * @param maxLiquidity Max liquidityGross permitido.
     * @return flipped true si paso de 0↔>0 en liquidityGross.
     */
    function update(
        mapping(int24 => Info) storage self,
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        bool upper,
        uint128 maxLiquidity
    ) internal returns (bool flipped) {
        Info storage info = self[tick];

        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter = liquidityDelta < 0
            ? liquidityGrossBefore - uint128(-liquidityDelta)
            : liquidityGrossBefore + uint128(liquidityDelta);

        if (liquidityGrossAfter > maxLiquidity) revert LiquidityGrossOverflow();

        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if (liquidityGrossBefore == 0) {
            // Convención: todo el growth previo ocurrio _below_ el tick
            if (tick <= tickCurrent) {
                info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
            }
            info.initialized = true;
        }

        info.liquidityGross = liquidityGrossAfter;

        // lower: +delta al cruzar L→R; upper: -delta al cruzar L→R
        info.liquidityNet = upper ? info.liquidityNet - liquidityDelta : info.liquidityNet + liquidityDelta;
    }

    /**
     * @notice Limpia el storage de un tick.
     * @param self Mapping de ticks.
     * @param tick Tick a borrar.
     */
    function clear(mapping(int24 => Info) storage self, int24 tick) internal {
        delete self[tick];
    }

    /**
     * @notice Cruza un tick: invierte feeGrowthOutside y retorna liquidityNet.
     * @param self Mapping de ticks.
     * @param tick Tick cruzado.
     * @param feeGrowthGlobal0X128 Fee growth global token0.
     * @param feeGrowthGlobal1X128 Fee growth global token1.
     * @return liquidityNet Delta de L al cruzar de izquierda a derecha.
     */
    function cross(
        mapping(int24 => Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal returns (int128 liquidityNet) {
        unchecked {
            Info storage info = self[tick];
            info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
            info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
            liquidityNet = info.liquidityNet;
        }
    }
}
