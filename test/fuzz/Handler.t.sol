// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Test, console} from "forge-std/Test.sol";
import "../../src/DSCEngine.sol";
import "../mocks/ERC20Mock.sol";
import "../../src/StableCoin.sol";

contract Handler is Test{
    DSCEngine dscEngine;
    StableCoin stableCoin;
    ERC20Mock weth;
    ERC20Mock wbtc;
    
    constructor(DSCEngine _dscEngine, StableCoin _stableCoin) {
        dscEngine = _dscEngine;
        stableCoin = _stableCoin;
        address[] memory _collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(_collateralTokens[0]);
        wbtc = ERC20Mock(_collateralTokens[1]);


    }

    function mintDSC(uint256 amount) public {
        amount = bound(amount, 1, type(uint96).max);
        (uint256 totalDscMinted, uint256 collateralValueUSD) = dscEngine.getAccountInformation(msg.sender);
        uint256 maxDscMinted = (collateralValueUSD / 2) - totalDscMinted;
        if(maxDscMinted < 0){
            return;
        }
        amount = bound(amount, 0, maxDscMinted);
        if(amount == 0){
            return;
        }
        
        vm.prank(msg.sender);
        dscEngine.mintDSC(amount);
    }

    function depositCollateral(uint256 collateralSeed, uint256 amount) public {
        // Bound the amount to avoid 0 (which reverts) and to avoid overflow
        amount = bound(amount, 1, type(uint96).max);
        ERC20Mock token = _getCollateralFromSeed(collateralSeed);
        
        // Mint the tokens to the random fuzzer address (msg.sender)
        vm.startPrank(msg.sender);
        token.mint(msg.sender, amount);
        token.approve(address(dscEngine), amount);
        dscEngine.depositCollateral(address(token), amount);
        vm.stopPrank();
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock){
        if(collateralSeed % 2 == 0){
            return weth;
        }
        return wbtc;
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amount) public {
        ERC20Mock token = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateral = dscEngine.getCollateralBalanceOfUser(msg.sender, address(token));
        
        if(maxCollateral == 0){
            return;
        }
        
        amount = bound(amount, 1, maxCollateral);
        
        // Prevent redeeming if it would break the health factor
        (uint256 totalDscMinted, uint256 collateralValueUSD) = dscEngine.getAccountInformation(msg.sender);
        if (totalDscMinted > 0) {
            uint256 amountToRedeemValueUSD = dscEngine.getUSDValue(address(token), amount);
            // If they redeem more than they have, or their new health factor drops below 1
            if (collateralValueUSD <= amountToRedeemValueUSD) {
                return;
            }
            uint256 newCollateralValueUSD = collateralValueUSD - amountToRedeemValueUSD;
            uint256 newMaxDscMintable = newCollateralValueUSD / 2;
            if (totalDscMinted > newMaxDscMintable) {
                return; // Health factor would break! Stop here to avoid revert.
            }
        }
        
        vm.prank(msg.sender);
        dscEngine.redeemCollateral(address(token), amount);
    }
}