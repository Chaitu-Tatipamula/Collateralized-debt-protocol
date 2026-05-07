# Decentralized Stablecoin Protocol

A decentralized, algorithmic stablecoin protocol allowing users to deposit collateral (such as WETH and WBTC) to mint a USD-pegged stablecoin (DSC). The system uses Chainlink price feeds to track collateral values and requires users to maintain a minimum health factor to avoid under-collateralization.

## Features Currently Implemented

- **StableCoin (`StableCoin.sol`)**: A custom ERC20 token (DSC) that is burnable and mintable exclusively by its owner (which will be the `DSCEngine`).
- **DSC Engine (`DSCEngine.sol`)**: The core logic handling the protocol mechanics:
  - **Collateral Deposits**: Users can deposit approved collateral tokens (e.g. WETH, WBTC).
  - **Minting DSC**: Users can mint the stablecoin against their deposited collateral, provided their health factor remains above the minimum threshold.
  - **Redeeming Collateral & Burning DSC**: Users can burn their stablecoin to redeem their deposited collateral.
  - **Health Factor Monitoring**: Calculates a user's health factor based on the collateral's USD value (fetched via Chainlink Oracles) to ensure the system remains safely over-collateralized.
  - *Note: Liquidation logic is currently stubbed and will be implemented in subsequent updates.*
