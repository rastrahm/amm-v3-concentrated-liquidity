// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {
    IdenticalAddresses,
    InvalidFee,
    PoolAlreadyExists,
    TickNotSpaced,
    Unauthorized,
    ZeroAddress
} from "./errors/CLErrors.sol";
import {CLPool} from "./CLPool.sol";
import {ICLFactory} from "./interfaces/ICLFactory.sol";

/**
 * @title CLFactory
 * @notice Despliega CLPool por (token0, token1, fee) y gestiona fee tiers.
 * @dev Adaptado de Uniswap v3 Factory (sin CREATE2 deployer / noDelegateCall).
 */
contract CLFactory is ICLFactory {
    /// @inheritdoc ICLFactory
    address public override owner;

    /// @inheritdoc ICLFactory
    mapping(uint24 => int24) public override feeAmountTickSpacing;

    /// @inheritdoc ICLFactory
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    /// @notice Ownership transferido.
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    /// @notice Fee tier habilitado.
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);
    /// @notice Pool creado.
    event PoolCreated(
        address indexed token0, address indexed token1, uint24 indexed fee, int24 tickSpacing, address pool
    );

    /**
     * @notice Inicializa owner y fee tiers estandar (500/3000/10000).
     */
    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        feeAmountTickSpacing[500] = 10;
        emit FeeAmountEnabled(500, 10);
        feeAmountTickSpacing[3000] = 60;
        emit FeeAmountEnabled(3000, 60);
        feeAmountTickSpacing[10000] = 200;
        emit FeeAmountEnabled(10000, 200);
    }

    /// @inheritdoc ICLFactory
    function createPool(address tokenA, address tokenB, uint24 fee) external override returns (address pool) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();

        int24 tickSpacing = feeAmountTickSpacing[fee];
        if (tickSpacing == 0) revert InvalidFee();
        if (getPool[token0][token1][fee] != address(0)) revert PoolAlreadyExists();

        pool = address(new CLPool(address(this), token0, token1, fee, tickSpacing));
        getPool[token0][token1][fee] = pool;
        getPool[token1][token0][fee] = pool;

        emit PoolCreated(token0, token1, fee, tickSpacing, pool);
    }

    /// @inheritdoc ICLFactory
    function setOwner(address owner_) external override {
        if (msg.sender != owner) revert Unauthorized();
        emit OwnerChanged(owner, owner_);
        owner = owner_;
    }

    /// @inheritdoc ICLFactory
    function enableFeeAmount(uint24 fee, int24 tickSpacing) public override {
        if (msg.sender != owner) revert Unauthorized();
        if (fee >= 1_000_000) revert InvalidFee();
        // Cap para evitar overflow en TickBitmap (Uniswap v3)
        if (tickSpacing <= 0 || tickSpacing >= 16384) revert TickNotSpaced();
        if (feeAmountTickSpacing[fee] != 0) revert InvalidFee();

        feeAmountTickSpacing[fee] = tickSpacing;
        emit FeeAmountEnabled(fee, tickSpacing);
    }
}
