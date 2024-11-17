// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployVault} from "../script/DeployVault.s.sol";
import {Vault} from "../src/Vault.sol";

contract VersionTest is Test {
    DeployVault private deployer;
    address private proxy;
    Vault private vault;
    address private owner = makeAddr("owner");

    function setUp() public {
        vault = new Vault();
        deployer = new DeployVault();
        proxy = deployer.run(owner);
        vault = Vault(proxy);
    }

    function test_get_version() public view {
        assertEq(vault.version(), 1, "Version does not match");
    }
}
