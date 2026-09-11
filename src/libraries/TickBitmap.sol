// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {TickNotSpaced} from "../errors/CLErrors.sol";
import {BitMath} from "./BitMath.sol";

/**
 * @title TickBitmap
 * @notice Estado empaquetado de ticks inicializados (256 ticks por word).
 * @dev Adaptado de Uniswap v3-core. Key = int16 (tick/spacing >> 8).
 */
library TickBitmap {
    /**
     * @notice Posicion (word, bit) del tick comprimido en el bitmap.
     * @param tick Tick ya dividido por tickSpacing.
     * @return wordPos Clave del mapping.
     * @return bitPos Bit dentro del word (0-255).
     */
    function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
        unchecked {
            wordPos = int16(tick >> 8);
            bitPos = uint8(int8(tick % 256));
        }
    }

    /**
     * @notice Invierte el bit de inicializacion de un tick alineado a spacing.
     * @param self Mapping bitmap.
     * @param tick Tick a flippear (debe ser multiplo de tickSpacing).
     * @param tickSpacing Espaciado del fee tier.
     */
    function flipTick(mapping(int16 => uint256) storage self, int24 tick, int24 tickSpacing) internal {
        unchecked {
            if (tick % tickSpacing != 0) revert TickNotSpaced();
            (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
            uint256 mask = 1 << bitPos;
            self[wordPos] ^= mask;
        }
    }

    /**
     * @notice Siguiente tick inicializado en la misma word (o word adyacente), hasta 256 ticks comprimidos.
     * @param self Mapping bitmap.
     * @param tick Tick de partida.
     * @param tickSpacing Espaciado.
     * @param lte true = buscar <= tick (izquierda); false = buscar > tick (derecha).
     * @return next Siguiente tick (inicializado o borde de word).
     * @return initialized true si el bit encontrado esta activo.
     */
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        unchecked {
            int24 compressed = tick / tickSpacing;
            if (tick < 0 && tick % tickSpacing != 0) compressed--; // round towards -inf

            if (lte) {
                (int16 wordPos, uint8 bitPos) = position(compressed);
                uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
                uint256 masked = self[wordPos] & mask;

                initialized = masked != 0;
                next = initialized
                    ? (compressed - int24(uint24(bitPos - BitMath.mostSignificantBit(masked)))) * tickSpacing
                    : (compressed - int24(uint24(bitPos))) * tickSpacing;
            } else {
                (int16 wordPos, uint8 bitPos) = position(compressed + 1);
                uint256 mask = ~((1 << bitPos) - 1);
                uint256 masked = self[wordPos] & mask;

                initialized = masked != 0;
                next = initialized
                    ? (compressed + 1 + int24(uint24(BitMath.leastSignificantBit(masked) - bitPos))) * tickSpacing
                    : (compressed + 1 + int24(uint24(type(uint8).max - bitPos))) * tickSpacing;
            }
        }
    }
}
