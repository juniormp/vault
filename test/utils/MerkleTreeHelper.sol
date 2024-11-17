// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

library MerkleTreeHelper {
    function generateMerkleRoot(
        bytes32[] memory leaves
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(leaves));
    }

    function generateProof(
        bytes32[] memory leaves,
        uint256 index
    ) public pure returns (bytes32[] memory) {
        require(index < leaves.length, "Index out of bounds");

        bytes32[] memory proof = new bytes32[](leaves.length - 1);
        uint256 proofIndex = 0;
        for (uint256 i = 0; i < leaves.length; i++) {
            if (i != index) {
                proof[proofIndex] = leaves[i];
                proofIndex++;
            }
        }
        return proof;
    }
}
