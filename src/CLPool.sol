// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {
    AlreadyInitialized,
    InsufficientToken0,
    InsufficientToken1,
    InvalidTickRange,
    InvalidTokenOrder,
    Locked,
    TickNotSpaced,
    ZeroAddress,
    ZeroLiquidity
} from "./errors/CLErrors.sol";
import {ICLMintCallback} from "./interfaces/ICLMintCallback.sol";
import {ICLPool} from "./interfaces/ICLPool.sol";
import {LiquidityMath} from "./libraries/LiquidityMath.sol";
import {Position} from "./libraries/Position.sol";
import {SafeCast} from "./libraries/SafeCast.sol";
import {SqrtPriceMath} from "./libraries/SqrtPriceMath.sol";
import {Tick} from "./libraries/Tick.sol";
import {TickBitmap} from "./libraries/TickBitmap.sol";
import {TickMath} from "./libraries/TickMath.sol";

/**
 * @title CLPool
 * @notice Pool de liquidez concentrada: initialize / mint / burn / collect (swap en Fase 5).
 * @dev Adaptado de Uniswap v3-core (sin oracle/TWAP). CEI + SafeERC20 + lock.
 */
contract CLPool is ICLPool {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    /// @inheritdoc ICLPool
    address public immutable override factory;
    /// @inheritdoc ICLPool
    address public immutable override token0;
    /// @inheritdoc ICLPool
    address public immutable override token1;
    /// @inheritdoc ICLPool
    uint24 public immutable override fee;
    /// @inheritdoc ICLPool
    int24 public immutable override tickSpacing;
    /// @inheritdoc ICLPool
    uint128 public immutable override maxLiquidityPerTick;

    /// @inheritdoc ICLPool
    Slot0 public override slot0;

    /// @inheritdoc ICLPool
    uint256 public override feeGrowthGlobal0X128;
    /// @inheritdoc ICLPool
    uint256 public override feeGrowthGlobal1X128;
    /// @inheritdoc ICLPool
    uint128 public override liquidity;

    /// @notice Bitmap de ticks inicializados.
    mapping(int16 => uint256) public tickBitmap;
    /// @notice Estado por tick.
    mapping(int24 => Tick.Info) public ticks;
    /// @notice Posiciones por keccak256(owner, tickLower, tickUpper).
    mapping(bytes32 => Position.Info) public positions;

    /// @notice Pool inicializado con precio.
    event Initialize(uint160 sqrtPriceX96, int24 tick);
    /// @notice Liquidez anadida a una posicion.
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );
    /// @notice Liquidez retirada (tokens a tokensOwed).
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );
    /// @notice Tokens cobrados de tokensOwed.
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    struct ModifyPositionParams {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        int128 liquidityDelta;
    }

    /**
     * @notice Crea el pool (tipicamente via factory).
     * @param factory_ Direccion de la factory.
     * @param token0_ Token0 (address < token1).
     * @param token1_ Token1.
     * @param fee_ Fee tier en hundredths of a bip.
     * @param tickSpacing_ Espaciado de ticks.
     */
    constructor(address factory_, address token0_, address token1_, uint24 fee_, int24 tickSpacing_) {
        if (factory_ == address(0) || token0_ == address(0) || token1_ == address(0)) revert ZeroAddress();
        if (token0_ >= token1_) revert InvalidTokenOrder();
        if (tickSpacing_ <= 0) revert TickNotSpaced();

        factory = factory_;
        token0 = token0_;
        token1 = token1_;
        fee = fee_;
        tickSpacing = tickSpacing_;
        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(tickSpacing_);
    }

    modifier lock() {
        if (!slot0.unlocked) revert Locked();
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    /// @inheritdoc ICLPool
    function initialize(uint160 sqrtPriceX96) external override {
        if (slot0.sqrtPriceX96 != 0) revert AlreadyInitialized();

        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick, unlocked: true});
        emit Initialize(sqrtPriceX96, tick);
    }

    /// @inheritdoc ICLPool
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        override
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        if (amount == 0) revert ZeroLiquidity();

        (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: recipient,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: SafeCast.toInt128(int256(uint256(amount)))
            })
        );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = _balance0();
        if (amount1 > 0) balance1Before = _balance1();

        ICLMintCallback(msg.sender).clMintCallback(amount0, amount1, data);

        if (amount0 > 0 && balance0Before + amount0 > _balance0()) revert InsufficientToken0();
        if (amount1 > 0 && balance1Before + amount1 > _balance1()) revert InsufficientToken1();

        emit Mint(msg.sender, recipient, tickLower, tickUpper, amount, amount0, amount1);
    }

    /// @inheritdoc ICLPool
    function burn(int24 tickLower, int24 tickUpper, uint128 amount)
        external
        override
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        if (amount == 0) revert ZeroLiquidity();

        (Position.Info storage position, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: msg.sender,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: SafeCast.toInt128(-int256(uint256(amount)))
            })
        );

        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            position.tokensOwed0 += uint128(amount0);
            position.tokensOwed1 += uint128(amount1);
        }

        emit Burn(msg.sender, tickLower, tickUpper, amount, amount0, amount1);
    }

    /// @inheritdoc ICLPool
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock returns (uint128 amount0, uint128 amount1) {
        Position.Info storage position = positions.get(msg.sender, tickLower, tickUpper);

        amount0 = amount0Requested > position.tokensOwed0 ? position.tokensOwed0 : amount0Requested;
        amount1 = amount1Requested > position.tokensOwed1 ? position.tokensOwed1 : amount1Requested;

        if (amount0 > 0) {
            position.tokensOwed0 -= amount0;
            IERC20(token0).safeTransfer(recipient, amount0);
        }
        if (amount1 > 0) {
            position.tokensOwed1 -= amount1;
            IERC20(token1).safeTransfer(recipient, amount1);
        }

        emit Collect(msg.sender, recipient, tickLower, tickUpper, amount0, amount1);
    }

    /**
     * @notice Lee liquidez y fees de una posicion.
     * @param owner Dueno.
     * @param tickLower Tick inferior.
     * @param tickUpper Tick superior.
     */
    function getPosition(address owner, int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position.Info storage position = positions.get(owner, tickLower, tickUpper);
        return (
            position.liquidity,
            position.feeGrowthInside0LastX128,
            position.feeGrowthInside1LastX128,
            position.tokensOwed0,
            position.tokensOwed1
        );
    }

    function _checkTicks(int24 tickLower, int24 tickUpper) private view {
        if (tickLower >= tickUpper) revert InvalidTickRange();
        if (tickLower < TickMath.MIN_TICK || tickUpper > TickMath.MAX_TICK) revert InvalidTickRange();
        if (tickLower % tickSpacing != 0 || tickUpper % tickSpacing != 0) revert TickNotSpaced();
    }

    function _modifyPosition(ModifyPositionParams memory params)
        private
        returns (Position.Info storage position, int256 amount0, int256 amount1)
    {
        _checkTicks(params.tickLower, params.tickUpper);

        Slot0 memory _slot0 = slot0;
        position = _updatePosition(params.owner, params.tickLower, params.tickUpper, params.liquidityDelta, _slot0.tick);

        if (params.liquidityDelta != 0) {
            if (_slot0.tick < params.tickLower) {
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                uint128 liquidityBefore = liquidity;

                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96, TickMath.getSqrtRatioAtTick(params.tickUpper), params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower), _slot0.sqrtPriceX96, params.liquidityDelta
                );

                liquidity = LiquidityMath.addDelta(liquidityBefore, params.liquidityDelta);
            } else {
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    function _updatePosition(address owner, int24 tickLower, int24 tickUpper, int128 liquidityDelta, int24 tick)
        private
        returns (Position.Info storage position)
    {
        position = positions.get(owner, tickLower, tickUpper);

        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128;
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128;

        bool flippedLower;
        bool flippedUpper;
        if (liquidityDelta != 0) {
            flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                false,
                maxLiquidityPerTick
            );
            flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                true,
                maxLiquidityPerTick
            );

            if (flippedLower) tickBitmap.flipTick(tickLower, tickSpacing);
            if (flippedUpper) tickBitmap.flipTick(tickUpper, tickSpacing);
        }

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            ticks.getFeeGrowthInside(tickLower, tickUpper, tick, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128);

        position.update(liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

        if (liquidityDelta < 0) {
            if (flippedLower) ticks.clear(tickLower);
            if (flippedUpper) ticks.clear(tickUpper);
        }
    }

    function _balance0() private view returns (uint256) {
        return IERC20(token0).balanceOf(address(this));
    }

    function _balance1() private view returns (uint256) {
        return IERC20(token1).balanceOf(address(this));
    }
}
