// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";
import {TransferHelper} from "v3-periphery/libraries/TransferHelper.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract VaultV2 is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    // State variables
    bytes32 private constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
    bytes32 private constant TRADER_ROLE = keccak256("TRADER_ROLE");

    ISwapRouter private swapRouter;
    bytes32 private merkleRoot;

    // Events
    event Swap(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event Withdrawal(
        address indexed withdrawer,
        address indexed tokenAddress,
        uint256 amount
    );

    // Errors
    error OnlyAdmin();
    error OnlyWithdrawer();
    error OnlyTrader();
    error NotWhitelisted();
    error DeadlineHasPassed();
    error PoolDoesNotExist();
    error InsufficientBalance();

    // Structs
    struct SwapParams {
        uint256 amountIn;
        uint256 amountOutMin;
        uint256 intermediateFee;
        address intermediateToken;
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint256 deadline;
        address aggregator;
        address factory;
        bytes32[] proof;
    }

    // Modifiers
    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdmin();
        }
        _;
    }

    modifier onlyWithdrawer() {
        if (!hasRole(WITHDRAWER_ROLE, msg.sender)) {
            revert OnlyWithdrawer();
        }
        _;
    }

    modifier onlyTrader() {
        if (!hasRole(TRADER_ROLE, msg.sender)) {
            revert OnlyTrader();
        }
        _;
    }

    modifier isWhitelistedAggregator(
        address _aggregator,
        bytes32[] calldata proof
    ) {
        bytes32 leaf = keccak256(abi.encodePacked(_aggregator));
        bool isWhitelisted = MerkleProof.verify(proof, merkleRoot, leaf);
        if (!isWhitelisted) {
            revert NotWhitelisted();
        }
        _;
    }

    // Constructor
    constructor() {
        _disableInitializers();
    }

    // External functions
    function initialize(
        address _withdrawer,
        address _trader
    ) external initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(WITHDRAWER_ROLE, _withdrawer);
        _grantRole(TRADER_ROLE, _trader);
    }

    function swap(
        SwapParams calldata params
    )
        external
        onlyTrader
        isWhitelistedAggregator(params.aggregator, params.proof)
        returns (uint256)
    {
        if (params.deadline < block.timestamp) revert DeadlineHasPassed();

        address pool = IUniswapV3Factory(params.factory).getPool(
            params.tokenIn,
            params.tokenOut,
            params.fee
        );
        if (pool == address(0)) revert PoolDoesNotExist();

        TransferHelper.safeTransferFrom(
            params.tokenIn,
            msg.sender,
            address(this),
            params.amountIn
        );
        TransferHelper.safeApprove(
            params.tokenIn,
            params.aggregator,
            params.amountIn
        );

        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: params.tokenIn,
                tokenOut: params.tokenOut,
                fee: params.fee,
                recipient: address(this),
                deadline: params.deadline,
                amountIn: params.amountIn,
                amountOutMinimum: params.amountOutMin,
                sqrtPriceLimitX96: 0
            });

        uint256 amountOut = ISwapRouter(params.aggregator).exactInputSingle(
            swapParams
        );

        emit Swap(
            msg.sender,
            params.tokenIn,
            params.tokenOut,
            params.amountIn,
            amountOut
        );

        return amountOut;
    }

    function withdraw(
        address tokenAddress,
        uint256 amount
    ) external onlyWithdrawer {
        if (IERC20(tokenAddress).balanceOf(address(this)) < amount) {
            revert InsufficientBalance();
        }
        IERC20(tokenAddress).transfer(msg.sender, amount);
        emit Withdrawal(msg.sender, tokenAddress, amount);
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyAdmin {
        merkleRoot = _merkleRoot;
    }

    function getMerkleRoot() external view returns (bytes32) {
        return merkleRoot;
    }

    // Public functions
    function version() public pure returns (uint256) {
        return 2;
    }

    // Internal functions
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyAdmin {}
}
