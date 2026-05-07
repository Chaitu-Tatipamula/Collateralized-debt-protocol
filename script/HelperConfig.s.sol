// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig{
        address wethUSDPriceFeed;
        address wbtcUSDPriceFeed;
        address weth;
        address wbtc;
    }

    NetworkConfig activeNetworkConfig;

    constructor() {

    }

    function getSepoliaNetworkConfig() public view returns (NetworkConfig config) {
        config = NetworkConfig({
            wethUSDPriceFeed : 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUSDPriceFeed : 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth : ,
            wbtc : ,    
        })
    }
}