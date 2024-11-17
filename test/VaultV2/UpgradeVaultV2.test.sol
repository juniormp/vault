// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployVault} from "../../script/DeployVault.s.sol";
import {UpgradeVaultV2} from "../../script/UpgradeVaultV2.s.sol";
import {Vault} from "../../src/Vault.sol";
import {VaultV2} from "../../src/VaultV2.sol";

contract DeployAndUpgrade is Test {
    DeployVault private deployer;
    UpgradeVaultV2 public upgrader;

    address public owner = makeAddr("owner");
    address public withdrawer = makeAddr("withdrawer");
    address public trader = makeAddr("trader");
    address public proxy;

    bytes32 private constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
    bytes32 private constant TRADER_ROLE = keccak256("TRADER_ROLE");

    error OnlyAdmin();

    function setUp() public {
        deployer = new DeployVault();
        upgrader = new UpgradeVaultV2();
        proxy = deployer.run(owner);
    }

    function test_upgrades() public {
        vm.prank(owner);
        VaultV2 vaultV2 = new VaultV2();

        uint8 version = 2;
        assertEq(version, vaultV2.version());
    }

    function test_revert_if_not_admin() public {
        address notAdmin = makeAddr("not_admin");

        vm.prank(owner);
        VaultV2 vaultV2 = new VaultV2();

        vm.expectRevert(Vault.OnlyAdmin.selector);
        upgrader.upgradeVault(address(proxy), address(vaultV2), notAdmin);
    }
}
