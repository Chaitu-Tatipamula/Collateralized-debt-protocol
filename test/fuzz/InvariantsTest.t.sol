// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {Handler} from "./Handler.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InvariantTest is StdInvariant, Test{
    DSCEngine dscEngine;
    StableCoin stableCoin;
    DeployDSC deployer;
    HelperConfig config;
    Handler handler;

    address weth;
    address wbtc;
    address wethUSDPriceFeed;
    address wbtcUSDPriceFeed;
    address public USER = makeAddr("USER");

    function setUp() public {
        deployer = new DeployDSC();
        (stableCoin, dscEngine, config) = deployer.run();
        handler = new Handler(dscEngine, stableCoin);
        targetContract(address(handler));
        

        (wethUSDPriceFeed, wbtcUSDPriceFeed, weth, wbtc, ) = config.activeNetworkConfig();
        
        uint256 amountToMint = 10e18;

        vm.prank(USER);
        ERC20Mock(weth).mint(USER, amountToMint);
        vm.prank(USER);
        ERC20Mock(weth).approve(address(dscEngine), amountToMint);
        vm.prank(USER);
        dscEngine.depositCollateralAndMintDSC(weth, amountToMint, 10e18);
    }

    function invariant_totalSupplyMustBeMoreThanTotalDscMinted() public {
        uint256 totalSupply = stableCoin.totalSupply();
        uint256 wethCollateral = IERC20(weth).balanceOf(address(dscEngine));
        uint256 wbtcCollateral = IERC20(wbtc).balanceOf(address(dscEngine));
        uint256 wethValue = dscEngine.getUSDValue(weth, wethCollateral);
        uint256 wbtcValue = dscEngine.getUSDValue(wbtc, wbtcCollateral);
        uint256 totalCollateral = wethValue + wbtcValue;
        //Total Collateral Value must be more than total supply
        assert(totalCollateral >= totalSupply);
    }


}