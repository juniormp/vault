// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployVault} from "../script/DeployVault.s.sol";
import {Vault} from "../src/Vault.sol";
import {MerkleTreeHelper} from "./utils/MerkleTreeHelper.sol";
import {UNISWAP_V3_SWAP_ROUTER} from "./utils/Constants.sol";

contract SetMerkleRootTest is Test {
    DeployVault private deployer;
    address private proxy;
    Vault private vault;

    address private owner = makeAddr("owner");
    address private whale = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;

    bytes32 private constant DEFAULT_ADMIN_ROLE = 0x00;

    function setUp() public {
        vault = new Vault();
        deployer = new DeployVault();
        proxy = deployer.run(owner);
        vault = Vault(proxy);
    }

    function test_set_merkle_root() public {
        vm.startPrank(owner);

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(makeAddr("nonwhitelisted")));
        leaves[1] = keccak256(abi.encodePacked(UNISWAP_V3_SWAP_ROUTER));
        bytes32 merkleRoot = MerkleTreeHelper.generateMerkleRoot(leaves);
        vault.setMerkleRoot(merkleRoot);

        assertEq(
            vault.getMerkleRoot(),
            merkleRoot,
            "Merkle root does not match"
        );
        vm.stopPrank();
    }

    function test_revert_if_not_admin() public {
        vm.startPrank(makeAddr("notOwner"));
        vm.expectRevert(Vault.OnlyAdmin.selector);
        vault.setMerkleRoot(keccak256(""));
    }
}
