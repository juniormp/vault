// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {VaultV2} from "../src/VaultV2.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract UpgradeVaultV2 is Script {
    function run(address owner) external returns (address) {
        address mostRecentDeployment = DevOpsTools.get_most_recent_deployment(
            "ERC1967Proxy",
            block.chainid
        );

        vm.startBroadcast(owner);
        VaultV2 vaultV2 = new VaultV2();
        address proxy = upgradeVault(
            mostRecentDeployment,
            address(vaultV2),
            owner
        );

        return proxy;
    }

    function upgradeVault(
        address proxyAddress,
        address newVAultAddress,
        address owner
    ) public returns (address) {
        vm.startBroadcast(owner);
        Vault proxy = Vault(proxyAddress);
        proxy.upgradeToAndCall(address(newVAultAddress), "");
        vm.stopBroadcast();

        return address(proxy);
    }
}
