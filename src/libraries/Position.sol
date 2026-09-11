// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {NoLiquidityPosition} from "../errors/CLErrors.sol";
import {FixedPoint128} from "./FixedPoint128.sol";
import {FullMath} from "./FullMath.sol";

/**
 * @title Position
 * @notice Liquidez y fees owed por (owner, tickLower, tickUpper).
 * @dev Adaptado de Uniswap v3-core.
 */
library Position {
    /// @notice Estado de una posicion.
    struct Info {
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /**
     * @notice Obtiene la posicion indexada por owner + rango.
     * @param self Mapping de posiciones.
     * @param owner Dueno de la posicion.
     * @param tickLower Tick inferior.
     * @param tickUpper Tick superior.
     * @return position Storage de la Info.
     */
    function get(mapping(bytes32 => Info) storage self, address owner, int24 tickLower, int24 tickUpper)
        internal
        view
        returns (Info storage position)
    {
        position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    /**
     * @notice Actualiza liquidez y acredita fees acumulados desde el ultimo update.
     * @param self Posicion a actualizar.
     * @param liquidityDelta Delta de liquidez (+ mint / - burn / 0 poke).
     * @param feeGrowthInside0X128 Fee growth inside actual token0.
     * @param feeGrowthInside1X128 Fee growth inside actual token1.
     */
    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        Info memory _self = self;

        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            if (_self.liquidity == 0) revert NoLiquidityPosition();
            liquidityNext = _self.liquidity;
        } else {
            liquidityNext = liquidityDelta < 0
                ? _self.liquidity - uint128(-liquidityDelta)
                : _self.liquidity + uint128(liquidityDelta);
        }

        // overflow en resta de fee growth es esperado (uint256 wrap)
        unchecked {
            uint128 tokensOwed0 = uint128(
                FullMath.mulDiv(
                    feeGrowthInside0X128 - _self.feeGrowthInside0LastX128, _self.liquidity, FixedPoint128.Q128
                )
            );
            uint128 tokensOwed1 = uint128(
                FullMath.mulDiv(
                    feeGrowthInside1X128 - _self.feeGrowthInside1LastX128, _self.liquidity, FixedPoint128.Q128
                )
            );

            if (liquidityDelta != 0) self.liquidity = liquidityNext;
            self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
            self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
            if (tokensOwed0 > 0 || tokensOwed1 > 0) {
                self.tokensOwed0 += tokensOwed0;
                self.tokensOwed1 += tokensOwed1;
            }
        }
    }
}
