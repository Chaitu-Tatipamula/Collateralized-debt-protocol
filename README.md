# Decentralized Stablecoin Protocol (DSC)

A robust, algorithmic, exogenous, collateralized decentralized stablecoin protocol. Users can deposit over-collateralized assets (such as WETH and WBTC) to mint a USD-pegged stablecoin (DSC). The protocol is architected with a MakerDAO-style CDP (Collateralized Debt Position) mechanism to maintain stability through algorithmic over-collateralization and liquidations.

## 🚀 Key Features

- **Collateral Management**: Seamlessly deposit and redeem crypto-assets (WETH & WBTC).
- **Algorithmic Minting**: Mint Decentralized Stablecoin (DSC) pegged $1-to-$1 with USD.
- **Robust Liquidation System**: Liquidators are incentivized with a 10% bonus to liquidate under-collateralized positions.
- **Chainlink Oracles**: Real-time asset pricing utilizing highly secure Chainlink decentralized oracle networks.
- **Strict Health Factor Enforcement**: Ensures the protocol remains strictly over-collateralized (200% Threshold) at all times.

## 🛠 Tech Stack

- **Solidity (^0.8.15)**: Smart contract development
- **Foundry**: Core development, testing, and deployment framework
- **OpenZeppelin Contracts (v5)**: Secure standards for ERC20 and Ownable components
- **Chainlink Brownie Contracts**: Real-world data feeds

## 🧪 Comprehensive Testing Suite

The protocol has been battle-tested with a robust suite of tests to ensure economic security:

- **Unit Testing**: Over a dozen granular unit tests verifying math precision and revert scenarios.
- **Mock Oracles**: Full integration with `MockV3Aggregator` to simulate intense market volatility and price crashes.
- **Fuzzing & Invariant Testing**: The protocol is stressed using `forge-std/StdInvariant`. Our custom `Handler.t.sol` handles state transitions, testing over 128,000 randomized state sequences to definitively prove the core invariant: **Total collateral value must ALWAYS exceed the total DSC supply.**

## 📜 Usage & Makefile Commands

A comprehensive Makefile is provided for streamlined project management.

### Build & Run
```bash
make build    # Compile the smart contracts
make test     # Execute the full test suite
make test-v   # Execute tests with maximum verbosity tracing
make format   # Format all Solidity code
```

### Local Network
```bash
make anvil    # Spin up a local Anvil testnet
```

### Deploy
```bash
# Deploy to local Anvil
make deploy-anvil

# Deploy to testnet (Sepolia)
make deploy-sepolia
```
