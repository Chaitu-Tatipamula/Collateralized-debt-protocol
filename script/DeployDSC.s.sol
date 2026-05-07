// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {StableCoin} from "../src/StableCoin.sol";

contract DeployDSC is Script {
    function run() external returns(StableCoin, DSCEngine) {
        vm.startBroadcast();
        StableCoin dsc = new StableCoin();
        // we should add tokens and price feeds from networkConfig
        // DSCEngine engine = new DSCEngine(, dsc, )
        vm.stopBroadcast();
    }
}