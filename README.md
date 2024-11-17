## Project Setup and Testing with Foundry


### Setting Up the Project

1. **Clone the Repository:**

   Begin by cloning the repository to your local machine:

   ```bash
   git clone git@github.com:juniormp/vault.git
   cd vault
   ```

2. **Compile the Contracts:**

   Compile the smart contracts to ensure everything is set up correctly:

   ```bash
   forge build
   ```

### Running Tests

To run the tests, use the following command. This command will fork the Ethereum mainnet at a specific block number to ensure consistent test results:

   ```bash
forge test --fork-url https://rpc.ankr.com/eth --fork-block-number 21203452
   ```

- **--fork-url**: Specifies the RPC URL to fork from. In this case, it uses Ankr's Ethereum RPC endpoint.
- **--fork-block-number**: Forks the blockchain at block number `21203452` to ensure tests are run against a consistent state.
- **-vvvv**: Sets the verbosity level to the maximum, providing detailed output during the test execution.

### Additional Commands

- **Clean the Build Artifacts:**

  If you need to clean up the build artifacts, use:

  ```bash
  forge clean
  ```

- **Update Dependencies:**

  To update the dependencies to their latest versions, run:

  ```bash
  forge update
  ```

# Vault Smart Contract Architecture

## Overview

The `Vault` smart contract is designed to securely manage institutional funds, aligning with the needs of organizations like Ava Labs. It leverages a proxy pattern for upgradability, role-based access control for security, and integration with a swap aggregator for efficient asset management. This contract serves as a Minimum Viable Product (MVP) to validate concepts. After further investigation with stakeholders and the team, it can be upgraded to provide a better market fit to our needs.

## Smart Contract Architecture

### Key Components

1. **Upgradeable Proxy Pattern:**
   - Utilizes the UUPS (Universal Upgradeable Proxy Standard) pattern from OpenZeppelin, allowing contract logic upgrades without changing the contract's address or losing its state.
   - The `_authorizeUpgrade` function is overridden to restrict upgrades to the admin role.

2. **Access Control:**
   - Employs `AccessControlUpgradeable` to manage roles and permissions, ensuring only authorized accounts can perform specific actions.

### Roles and Responsibilities

1. **Admin Role:**
   - Responsible for upgrading the contract, granted the `DEFAULT_ADMIN_ROLE`.
   - Ensures only authorized upgrades through the `_authorizeUpgrade` function.

2. **Withdrawer Role:**
   - Granted the `WITHDRAWER_ROLE`, the only role authorized to withdraw tokens from the vault.
   - Prevents unauthorized withdrawals by restricting this function to designated accounts.

3. **Trader Role:**
   - Granted the `TRADER_ROLE`, the only role allowed to execute token swaps through the vault.
   - Integrated with a swap aggregator for secure and efficient trading.

### Integration with Swap Aggregator

- The vault is integrated with a swap aggregator, such as Uniswap V3, to facilitate token swaps.
- The `swap` function allows only the trader role to execute swaps, using the `ISwapRouter` interface and `TransferHelper` library for secure token transfers.

## Merkle Tree for Whitelisted Aggregators

### Overview

The contract uses a Merkle Tree to manage a list of whitelisted aggregators, ensuring only authorized entities can interact with the vault.

1. **Merkle Root:**
   - Stores a `merkleRoot` representing the root of the Merkle Tree, summarizing all the leaves (aggregators).

2. **Whitelisting Aggregators:**
   - Aggregators are represented as leaves in the Merkle Tree, with each leaf being a hash of the aggregator's address.
   - The `isWhitelistedAggregator` modifier verifies if an aggregator is part of the tree using the `MerkleProof.verify` function.

### Testing the Merkle Tree

The `MerkleTreeHelper` library provides utility functions for testing:

1. **Generate Merkle Root:**
   - Computes the Merkle Root from an array of leaves (aggregator addresses).

2. **Generate Proof:**
   - Creates a proof for a specific leaf (aggregator) in the tree, used in tests to verify whitelisting.

3. **Testing Approach:**
   - Tests ensure the `isWhitelistedAggregator` modifier correctly verifies aggregators using the generated proof.
   - Edge cases, such as having only one leaf or the leaf being at index 0, are tested for robustness.

## Task Assignment Fulfillment

The smart contract vault fulfills the following requirements:

- **Admin Role for Upgrades:**
  - Includes an admin role for contract upgrades, protected by access control.

- **Withdrawer Role:**
  - Defines a withdrawer role as the sole role permitted to withdraw tokens.

- **Trader Role:**
  - Includes a trader role exclusively allowed to trade tokens through the vault.

## Alignment with Ava Labs' Needs

1. **Restricted Access and Controlled Usage:**
   - Roles ensure only authorized individuals manage funds, aligning with institutional needs.

2. **Institutional Use of Liquidity:**
   - Allows strategic deployment of liquidity, optimizing treasury allocations and yield strategies.

3. **Aggregator Integration:**
   - Provides flexibility in managing multiple assets across protocols, ideal for treasury management.

4. **Closed to Public Interactions:**
   - Restricts interactions to authorized roles, minimizing security risks and maintaining control.

5. **Security and Upgradability:**
   - Security features and upgradability allow adaptation to new standards and integrations over time.

This approach provides a dedicated, flexible, and secure vault for managing liquidity and assets across various EVM-compatible DeFi protocols, aligning with the requirements for safe and efficient treasury operations. As an MVP, it sets the foundation for further enhancements based on feedback and evolving needs.

## Contract Upgrade Mechanism

### Overview

The `Vault` contract utilizes the UUPS (Universal Upgradeable Proxy Standard) pattern provided by the OpenZeppelin library to enable contract upgrades. This pattern allows for the separation of the contract's logic and data, enabling upgrades without losing the contract's state.

### How It Works

1. **Proxy Pattern:**
   - The `Vault` contract is deployed behind an `ERC1967Proxy`. This proxy delegates calls to the implementation contract, allowing the logic to be upgraded while maintaining the same address and state.
   - The proxy holds the state, while the implementation contract contains the logic.

2. **UUPSUpgradeable:**
   - The `Vault` and `VaultV2` contracts inherit from `UUPSUpgradeable`, which provides the necessary functions to upgrade the contract.
   - The `_authorizeUpgrade` function is overridden to include access control, ensuring only authorized accounts can perform upgrades.

3. **OpenZeppelin Libraries:**
   - The OpenZeppelin libraries provide secure and tested implementations of upgradeable contracts, reducing the risk of vulnerabilities.

### Upgrade Process

The upgrade process involves deploying a new version of the contract (`VaultV2`) and updating the proxy to point to this new implementation. This is done using the `UpgradeVaultV2` script:

1. **Deployment:**
   - The `UpgradeVaultV2` script retrieves the most recent deployment of the proxy and deploys the new `VaultV2` contract.

2. **Upgrade:**
   - The `upgradeVault` function is called to update the proxy's implementation address to the new `VaultV2` contract.
   - The `upgradeToAndCall` function is used to perform the upgrade, ensuring the new implementation is initialized if necessary.

### Testing

The upgrade process was tested using the following approach:

1. **Unit Tests:**
   - The `UpgradeVaultV2.test.sol` file contains unit tests to verify the upgrade process.
   - The `test_upgrades` function checks that the new version of the contract is correctly deployed and the version number is updated.

2. **Access Control:**
   - The `test_revert_if_not_admin` function ensures that only accounts with the appropriate admin role can perform upgrades, preventing unauthorized changes.

By following these steps, the contract can be safely upgraded while maintaining its state and ensuring only authorized upgrades are performed. For more detailed instructions on deploying and upgrading contracts, please refer to the comments and documentation within the codebase.

## Deployment Security Instructions For Production

### Task Assignment Deployment

The `DeployVault` contract is designed for task assignment purposes. It provides a simple way to deploy the `Vault` contract using a proxy pattern. This approach is suitable for development and testing environments.

### Production Deployment Strategies

For production environments, it is recommended to use more robust deployment strategies to ensure security and reliability. Below are some suggested methods:

#### Foundry Cast

Foundry Cast is a powerful tool that follows the ERC-2335: BLS12-381 Keystore specification. It allows for secure management of wallets and deployment of contracts.

1. **Import Wallet:**

   Use the following command to import your wallet interactively:

   ```bash
   cast wallet import myWallet --interactive
   ```

2. **List Wallets:**

   To list all available wallets, use:

   ```bash
   cast wallet list
   ```

3. **Deploy Contract:**

   For added security, include a `.password` file:

   ```bash
   forge script script/DeployVault.s.sol --rpc-url $RPC_URL --account myWallet --trader 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --withdrawer 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast -vvvv --password-file
   ```

5. **Keystore Management:**

   Check the keystore for your wallet:

   ```bash
   ls .foundry/keystores/myWallet
   ```

#### AWS Parameter Store Integration

For enhanced security, consider integrating with AWS Parameter Store to retrieve private keys in a cryptographically secure manner. This approach ensures that sensitive information is not exposed during the deployment process.

## Testing Structure

The testing suite for the `Vault` smart contract follows the [Branching Tree Technique Pattern](https://www.youtube.com/watch?v=0-EmbNVgFA4). This approach ensures comprehensive coverage by systematically exploring different paths and conditions within the contract's logic. Below is an overview of the test structure and methodology:

### Overview

The Branching Tree Technique Pattern is a systematic approach to testing that involves:

1. **Identifying Key Functionalities:**
   - Each test file targets specific functionalities of the `Vault` contract, such as swapping, withdrawing, setting the Merkle root, and upgrading the contract.

2. **Branching Scenarios:**
   - For each functionality, tests are designed to cover various scenarios, including successful operations, edge cases, and expected failures.

3. **Modifiers and Setup:**
   - Common setup steps and role assignments are encapsulated in modifiers to ensure consistency and reduce redundancy across tests.
