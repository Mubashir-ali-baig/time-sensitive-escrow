# Time Sensitive Upgradeable Escrow

This project implements an upgradeable escrow system using Solidity. The escrow contract allows users to deposit, claim, and redeem ERC20 tokens or Ether under time-based constraints. The system is designed with gas efficiency, security, and flexibility in mind, leveraging UUPS upgradeability for seamless contract upgrades. It showcases
the upgradeability through the addition of Ether deposit support in the EscrowV2 and how the ERC1967Proxy is used with UUPS to upgrade from v1 to v2. 

## Features
- **ERC20 and Ether Support**: Users can deposit and manage both ERC20 tokens and Ether.
- **Upgradeable**: Utilizes UUPS (Universal Upgradeable Proxy Standard) for seamless upgrades.
- **Security**: Implements non-reentrancy and proper storage layout for safety.
- **Time-Based Claims**: Funds can only be claimed or redeemed within specific intervals.
- **Fail-Safe Design**: Handles edge cases like invalid IDs, expired claims, and zero-amount transactions.

## Prerequisites
Before starting, ensure you have the following installed:
- [Node.js](https://nodejs.org/) (v14 or later)
- [Foundry](https://book.getfoundry.sh/) (Rust-based Ethereum development toolkit)
- [Git](https://git-scm.com/)
- [Solc](https://soliditylang.org/) (Solidity compiler, compatible with version ^0.8.15)

## Installation Steps

### 1. Clone the Repository
```bash
git clone https://github.com/Mubashir-ali-baig/time-sensitive-escrow.git
cd escrow-contracts
```

### 2. Install Dependencies
Ensure you have [Foundry](https://book.getfoundry.sh/getting-started/installation) installed. Then, run the following command to install dependencies:
```bash
forge install
```

### 3. Compile the Contracts
Compile the Solidity contracts to ensure everything is set up correctly:
```bash
forge build
```

### 4. Run Tests
Execute the test suite to verify the contracts:
```bash
forge test
```

## Project Structure
- **`contracts/`**: Contains the main contract files.
  - `EscrowV1.sol`: First version of the escrow contract.
  - `EscrowV2.sol`: Upgraded version with additional functionality.
- **`libraries/`**: Utility libraries like `TransferHelper`.
- **`interfaces/`**: Contract interfaces like `IEscrowV1` and `IEscrowV2`.
- **`test/`**: Test files for contracts.
- **`script/`**: Deployment and upgrade scripts.
- **`foundry.toml`**: Foundry configuration file.

## Key Commands

### Compile Contracts
```bash
forge build
```

### Run Tests
```bash
forge test
```

### Deploy the Contract
Customize the `script/DeployEscrowV1.s.sol` or `script/UpgradeEscrowV1.s.sol` script, and then deploy:
```bash
forge script script/DeployEscrowV1.s.sol --broadcast --rpc-url <RPC_URL>
```
Replace `<RPC_URL>` with your Ethereum network endpoint (e.g., Alchemy, Infura).

### Run a Script
```bash
forge script <SCRIPT_PATH> --broadcast --rpc-url <RPC_URL>
```

## Contribution
Feel free to contribute to this project by opening issues or submitting pull requests. Please ensure all tests pass before submitting any changes.

## License
This project is licensed under the MIT License.
