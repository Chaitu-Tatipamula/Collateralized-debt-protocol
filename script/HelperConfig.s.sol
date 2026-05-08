// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    uint8 constant DECIMALS = 8;
    int256 constant INITIAL_PRICE = 2000e8;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        address wethUSDPriceFeed;
        address wbtcUSDPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaNetworkConfig() public view returns (NetworkConfig memory config) {
        config = NetworkConfig({
            wethUSDPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUSDPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
            wbtc: 0x29f2D40B0605204364af54EC677bD022dA425d03,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory config) {
        if (activeNetworkConfig.wethUSDPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator mockWethUSDPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        MockV3Aggregator mockWbtcUSDPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);

        ERC20Mock weth = new ERC20Mock("Wrapped ETH", "WETH", msg.sender, 100e18);
        ERC20Mock wbtc = new ERC20Mock("Wrapped BTC", "WBTC", msg.sender, 100e18);
        vm.stopBroadcast();

        config = NetworkConfig({
            wethUSDPriceFeed: address(mockWethUSDPriceFeed),
            wbtcUSDPriceFeed: address(mockWbtcUSDPriceFeed),
            weth: address(weth),
            wbtc: address(wbtc),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}
