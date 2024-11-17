// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployVault} from "../script/DeployVault.s.sol";
import {Vault} from "../src/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MerkleTreeHelper} from "./utils/MerkleTreeHelper.sol";
import {WETH, DAI, UNISWAP_V3_SWAP_ROUTER, UNISWAP_V3_FACTORY} from "./utils/Constants.sol";
import {IWETH} from "./utils/IWETH.sol";

contract WithdrawTest is Test {
    DeployVault private deployer;
    address private proxy;
    Vault private vault;

    IWETH private constant weth = IWETH(WETH);

    address private withdrawer = makeAddr("withdrawer");
    address private owner = makeAddr("owner");
    address private whale = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;

    bytes32 private constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 private constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

    error InsufficientBalance();
    error OnlyWithdrawer();

    event Withdrawal(
        address indexed withdrawer,
        address indexed tokenAddress,
        uint256 amount
    );

    function setUp() public {
        vault = new Vault();
        deployer = new DeployVault();
        proxy = deployer.run(owner);
        vault = Vault(proxy);
    }

    modifier grantWithdrawerRole(address _user) {
        vm.prank(owner);
        vault.grantRole(WITHDRAWER_ROLE, _user);
        _;
    }

    modifier vaultHasFunds(uint256 _amount) {
        vm.prank(whale);
        weth.transfer(address(vault), _amount);
        _;
    }

    function test_successful_withdrawal()
        public
        grantWithdrawerRole(withdrawer)
        vaultHasFunds(10 ether)
    {
        vm.startPrank(withdrawer);

        uint256 balanceVaultBefore = weth.balanceOf(address(vault));
        uint256 amountWithdrawn = 10 ether;
        vault.withdraw(WETH, amountWithdrawn);
        uint256 balanceVaultAfter = weth.balanceOf(address(vault));

        assertEq(balanceVaultBefore, amountWithdrawn);
        assertEq(balanceVaultAfter, balanceVaultBefore - amountWithdrawn);

        vm.stopPrank();
    }

    function test_partial_withdrawal()
        public
        grantWithdrawerRole(withdrawer)
        vaultHasFunds(20 ether)
    {
        vm.startPrank(withdrawer);

        uint256 initialBalance = weth.balanceOf(address(vault));
        uint256 amountWithdrawn = 10 ether;

        vault.withdraw(WETH, amountWithdrawn);

        uint256 finalBalance = weth.balanceOf(address(vault));

        assertEq(
            finalBalance,
            initialBalance - amountWithdrawn,
            "Vault balance should decrease by the partial withdrawal amount"
        );

        vm.stopPrank();
    }

    function test_emit_event_Withdrawal()
        public
        grantWithdrawerRole(withdrawer)
        vaultHasFunds(10 ether)
    {
        vm.startPrank(withdrawer);

        uint256 amountWithdrawn = 10 ether;

        vm.expectEmit(true, true, true, true);
        emit Withdrawal(withdrawer, WETH, amountWithdrawn);

        vault.withdraw(WETH, amountWithdrawn);

        vm.stopPrank();
    }

    function test_insufficient_balance_reverts()
        public
        grantWithdrawerRole(withdrawer)
    {
        vm.startPrank(withdrawer);

        uint256 amountWithdrawn = 10 ether;

        vm.expectRevert(InsufficientBalance.selector);

        vault.withdraw(WETH, amountWithdrawn);

        vm.stopPrank();
    }

    function test_unauthorized_withdrawal_reverts() public {
        vm.startPrank(makeAddr("nonWithdrawer"));

        uint256 amountWithdrawn = 10 ether;

        vm.expectRevert(OnlyWithdrawer.selector);

        vault.withdraw(WETH, amountWithdrawn);

        vm.stopPrank();
    }

    function test_zero_amount_withdrawal()
        public
        grantWithdrawerRole(withdrawer)
        vaultHasFunds(10 ether)
    {
        vm.startPrank(withdrawer);

        uint256 initialBalance = weth.balanceOf(address(vault));

        vault.withdraw(WETH, 0);

        uint256 finalBalance = weth.balanceOf(address(vault));

        assertEq(
            initialBalance,
            10 ether,
            "Initial vault balance should be 10 ether"
        );
        assertEq(
            finalBalance,
            initialBalance,
            "Vault balance should remain unchanged after zero amount withdrawal"
        );

        vm.stopPrank();
    }

    function test_withdrawal_after_role_revocation()
        public
        grantWithdrawerRole(withdrawer)
    {
        vm.startPrank(owner);
        vault.revokeRole(WITHDRAWER_ROLE, withdrawer);
        vm.stopPrank();

        vm.startPrank(withdrawer);

        uint256 amountWithdrawn = 10 ether;

        vm.expectRevert(OnlyWithdrawer.selector);
        vault.withdraw(WETH, amountWithdrawn);

        vm.stopPrank();
    }

    function test_withdraw_invalid_token_address()
        public
        grantWithdrawerRole(withdrawer)
    {
        vm.startPrank(withdrawer);

        address invalidToken = address(0);
        uint256 amountWithdrawn = 10 ether;

        vm.expectRevert();
        vault.withdraw(invalidToken, amountWithdrawn);

        vm.stopPrank();
    }
}
