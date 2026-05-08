// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DSCEngine dscEngine;
    StableCoin stableCoin;
    HelperConfig config;
    address wethUSDPriceFeed;
    address weth;
    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant COLLATERAL_AMOUNT = 5e18;
    uint256 public constant INITIAL_BALANCE = 1000e18;
    address[] public tokens;
    address[] public priceFeeds;
    
    function setUp() public {
        deployer = new DeployDSC();
        (stableCoin, dscEngine, config) = deployer.run();
        (wethUSDPriceFeed, , weth, , ) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, INITIAL_BALANCE);
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }
    
    modifier depositCollateraAndMintDSC() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateralAndMintDSC(weth, COLLATERAL_AMOUNT, 10e18);
        vm.stopPrank();
        _;
    }

    function testRevertIfNotInitializedCorrectly() public {
        vm.startPrank(USER);
        tokens.push(weth);
        priceFeeds.push(wethUSDPriceFeed);
        priceFeeds.push(wethUSDPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__InvalidTokenLengthAndPriceFeedsLength.selector);
        new DSCEngine(tokens, priceFeeds, address(stableCoin));
        vm.stopPrank();
    }

    function testGetUSDValue() public view{
        uint256 ethAmount = 5e18;
        uint256 expectedUSDValue = 10000e18;
        uint256 actualUSDValue = dscEngine.getUSDValue(weth, ethAmount);
        assertEq(actualUSDValue, expectedUSDValue);
    }

    function testGetTokenAmountFromUSD() public view{
        uint256 usdAmount = 2000e18;
        uint256 expectedTokenAmount = 1 ether;
        uint256 actualTokenAmount = dscEngine.getTokenAmountFromUSD(weth, usdAmount);
        assertEq(actualTokenAmount, expectedTokenAmount);
    }
    
    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        vm.startPrank(USER);
        ERC20Mock token = new ERC20Mock("test token", "TT", USER, INITIAL_BALANCE);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(address(token), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testRevertIfTransferFail() public {
        vm.startPrank(USER);
        // ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectRevert();
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    // function testCollateralDepositActions() public {
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
    //     vm.expectEmit(true, true, true, false);
    //     dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
    //     vm.stopPrank();
    // }

    function testCanDepositAndGetAccountInformation() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueUSD) = dscEngine.getAccountInformation(USER);
        uint256 expectedMinted = 0;
        uint256 expectedCollateralTokenAmount = dscEngine.getTokenAmountFromUSD(weth, collateralValueUSD);
        assertEq(totalDscMinted, expectedMinted);
        assertEq(COLLATERAL_AMOUNT, expectedCollateralTokenAmount);
    }

    function testGetCollateral() public depositCollateral {
        uint256 actualCollateralValue = dscEngine.getCollateralValue(USER);
        uint256 expectedCollateral = dscEngine.getUSDValue(weth, COLLATERAL_AMOUNT);
        assertEq(expectedCollateral, actualCollateralValue);
    }

    function testRedeemCollateral() public depositCollateral() {
        vm.startPrank(USER);
        (uint256 totalDscMintedBeginning, uint256 collateralValueUSDBeginning) = dscEngine.getAccountInformation(USER);
        dscEngine.redeemCollateral(weth, COLLATERAL_AMOUNT);
        (uint256 totalDscMintedEnding, uint256 collateralValueUSDEnding) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMintedBeginning, totalDscMintedEnding);
        assertEq(0, collateralValueUSDEnding);
        vm.stopPrank();
    }

    function testBurnDSC() public depositCollateral{
        vm.startPrank(USER);
        dscEngine.mintDSC(10e18);
        (uint256 totalDscMinted, uint256 collateralValueUSD) = dscEngine.getAccountInformation(USER);
        ERC20Mock(address(stableCoin)).approve(address(dscEngine), totalDscMinted);
        dscEngine.burnDSC(totalDscMinted);
        (uint256 totalDscMintedEnding, uint256 collateralValueUSDEnding) = dscEngine.getAccountInformation(USER);
        assertEq(0, totalDscMintedEnding);
        assertEq(collateralValueUSD, collateralValueUSDEnding);
        vm.stopPrank();
    }

    function testGetHealthFactorAndLiquidate() public depositCollateraAndMintDSC{
        vm.startPrank(USER);
        // should be 500000000000000000000 2000e8 * 1e10 * 5e18/ 1e18 = 10000e18 -> 10000e18 * 50/100 = 5000e18 * 1e18/10e18 = 5e18
        uint256 healthFactor = dscEngine.getHealthFactor();
        console.log("Health Factor: ", healthFactor);
        assertGt(healthFactor, dscEngine.getMinHealthFactor());
        vm.stopPrank();
        vm.startPrank(LIQUIDATOR);
        // Liquidator needs DSC to pay off the user's debt, so they mint their own first
        // They need enough collateral to survive the upcoming price crash themselves!
        ERC20Mock(weth).mint(LIQUIDATOR, 1000e18);
        ERC20Mock(weth).approve(address(dscEngine), 1000e18);
        dscEngine.depositCollateralAndMintDSC(weth, 1000e18, 10e18); // Mint 10 DSC
        vm.stopPrank();

        // Now we crash the price of the collateral to break the USER's health factor!
        int256 ethCrashPrice = 3e8; // Crash price from $2000 to $3
        MockV3Aggregator(wethUSDPriceFeed).updateAnswer(ethCrashPrice);
        
        vm.startPrank(LIQUIDATOR);
        // Approve the engine to take the liquidator's DSC
        ERC20Mock(address(stableCoin)).approve(address(dscEngine), 1e18);
        
        // Now the liquidator liquidates the user!
        dscEngine.liquidate(weth, USER, 1e18);
        vm.stopPrank();
    }
    
    
    
}