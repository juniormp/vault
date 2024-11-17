// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployVault} from "../script/DeployVault.s.sol";
import {Vault} from "../src/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MerkleTreeHelper} from "./utils/MerkleTreeHelper.sol";
import {WETH, DAI, USDC, UNISWAP_V3_SWAP_ROUTER, UNISWAP_V3_FACTORY} from "./utils/Constants.sol";
import {IWETH} from "./utils/IWETH.sol";

contract SwapTest is Test {
    DeployVault private deployer;
    address private proxy;
    Vault private vault;

    IWETH private constant weth = IWETH(WETH);
    IERC20 private constant dai = IERC20(DAI);
    uint24 private constant poolFee = 3000;

    address private trader = makeAddr("trader");
    address private owner = makeAddr("owner");
    address private whale = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;

    bytes32 private constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 private constant TRADER_ROLE = keccak256("TRADER_ROLE");

    bytes32[] proof;

    event Swap(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    function setUp() public {
        vm.prank(whale);
        weth.transfer(trader, 1000 ether);

        vault = new Vault();
        deployer = new DeployVault();
        proxy = deployer.run(owner);
        vault = Vault(proxy);
    }

    modifier grantTraderRole(address _user) {
        vm.prank(owner);
        vault.grantRole(TRADER_ROLE, _user);
        _;
    }

    modifier whitelistAggregator(address _aggregator) {
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(makeAddr("nonwhitelisted")));
        leaves[1] = keccak256(abi.encodePacked(_aggregator));
        bytes32 merkleRoot = MerkleTreeHelper.generateMerkleRoot(leaves);
        proof = MerkleTreeHelper.generateProof(leaves, 1);

        vm.prank(owner);
        vault.setMerkleRoot(merkleRoot);
        _;
    }

    function test_successful_swap()
        public
        grantTraderRole(trader)
        whitelistAggregator(UNISWAP_V3_SWAP_ROUTER)
    {
        vm.startPrank(trader);

        uint256 balanceVaultBefore = dai.balanceOf(address(vault));
        weth.approve(address(vault), type(uint256).max);
        Vault.SwapParams memory params = Vault.SwapParams({
            amountIn: 1 ether,
            amountOutMin: 1,
            tokenIn: WETH,
            tokenOut: DAI,
            fee: poolFee,
            deadline: block.timestamp,
            aggregator: UNISWAP_V3_SWAP_ROUTER,
            factory: UNISWAP_V3_FACTORY,
            proof: proof
        });

        uint256 amountOut = vault.swap(params);

        uint256 balanceVaultAfter = dai.balanceOf(address(vault));
        assertEq(
            balanceVaultBefore,
            0 ether,
            "Initial vault balance should be 0 DAI"
        );
        assertEq(
            balanceVaultAfter,
            balanceVaultBefore + amountOut,
            "Vault balance should increase by the swap amount"
        );

        vm.stopPrank();
    }

    function test_swap_reverts_if_DeadlineHasPassed()
        public
        grantTraderRole(trader)
        whitelistAggregator(UNISWAP_V3_SWAP_ROUTER)
    {
        vm.startPrank(trader);

        weth.approve(address(vault), 1 ether);

        Vault.SwapParams memory params = Vault.SwapParams({
            amountIn: 1 ether,
            amountOutMin: 1,
            tokenIn: WETH,
            tokenOut: DAI,
            fee: poolFee,
            deadline: block.timestamp - 1,
            aggregator: UNISWAP_V3_SWAP_ROUTER,
            factory: UNISWAP_V3_FACTORY,
            proof: proof
        });

        vm.expectRevert(Vault.DeadlineHasPassed.selector);
        vault.swap(params);

        vm.stopPrank();
    }

    function test_swap_reverts_if_aggregator_NotWhitelisted()
        public
        grantTraderRole(trader)
    {
        vm.startPrank(trader);

        weth.approve(address(vault), 1 ether);

        Vault.SwapParams memory params = Vault.SwapParams({
            amountIn: 1 ether,
            amountOutMin: 1,
            tokenIn: WETH,
            tokenOut: DAI,
            fee: poolFee,
            deadline: block.timestamp,
            aggregator: UNISWAP_V3_SWAP_ROUTER,
            factory: UNISWAP_V3_FACTORY,
            proof: proof
        });

        vm.expectRevert(Vault.NotWhitelisted.selector);
        vault.swap(params);

        vm.stopPrank();
    }

    function test_swap_reverts_if_UserNotTrader()
        public
        whitelistAggregator(UNISWAP_V3_SWAP_ROUTER)
    {
        vm.startPrank(makeAddr("nonTrader"));

        weth.approve(address(vault), 1 ether);

        Vault.SwapParams memory params = Vault.SwapParams({
            amountIn: 1 ether,
            amountOutMin: 1,
            tokenIn: WETH,
            tokenOut: DAI,
            fee: poolFee,
            deadline: block.timestamp,
            aggregator: UNISWAP_V3_SWAP_ROUTER,
            factory: UNISWAP_V3_FACTORY,
            proof: proof
        });

        vm.expectRevert(Vault.OnlyTrader.selector);
        vault.swap(params);

        vm.stopPrank();
    }

    function test_emit_event_Swap()
        public
        grantTraderRole(trader)
        whitelistAggregator(UNISWAP_V3_SWAP_ROUTER)
    {
        vm.startPrank(trader);

        uint256 amountIn = 1 ether;
        uint256 amountOutMin = 1;
        weth.approve(address(vault), amountIn);

        Vault.SwapParams memory params = Vault.SwapParams({
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            tokenIn: WETH,
            tokenOut: DAI,
            fee: poolFee,
            deadline: block.timestamp,
            aggregator: UNISWAP_V3_SWAP_ROUTER,
            factory: UNISWAP_V3_FACTORY,
            proof: proof
        });

        uint256 amountsOut = 3130681382513480965751; // mocked value from block number 21203452
        vm.expectEmit(true, true, true, true);
        emit Swap(trader, WETH, DAI, amountIn, amountsOut);
        vault.swap(params);

        vm.stopPrank();
    }
}
