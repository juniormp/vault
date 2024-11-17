// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// @todo This deployment script is for testing purposes only.
// For production deployment, please refer to the README.md for detailed instructions
// to use secure deployment strategies like Foundry Cast and AWS Parameter Store.
contract DeployVault is Script {
    function run(address owner) external returns (address) {
        address proxy = deployVault(owner);
        return proxy;
    }

    function deployVault(address owner) public returns (address) {
        address _withdrawer = makeAddr("withdrawer");
        address _trader = makeAddr("trader");

        vm.startBroadcast(owner);
        Vault vault = new Vault();
        bytes memory data = abi.encodeWithSelector(
            Vault.initialize.selector,
            _withdrawer,
            _trader
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(vault), data);
        vm.stopBroadcast();

        return address(proxy);
    }
}
