// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;
import {StableCoin} from "./StableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
    error DSCEngine__AmountMustBeMoreThanZero();
    error DSCEngine__InvalidTokenLengthAndPriceFeedsLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__MintingFailed();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsBroken(uint256 healthFactor);
    error DSCEngine__HealthFactorOK();
    error DSCEngine__HealthFactorNotImproved();

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposits;
    mapping(address user => uint256 amountDscMinted) private s_amountDscMinted;
    address[] private s_collateralTokens;

    StableCoin private immutable i_dsc;

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event DSCMinted(address indexed user, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemFrom, address indexed redeemTo, address tokenCollateral, uint256 amount
    );

    modifier mustBeMoreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__AmountMustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _address) {
        if (s_priceFeeds[_address] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    constructor(address[] memory _tokens, address[] memory _priceFeeds, address _dsc) {
        if (_tokens.length != _priceFeeds.length) {
            revert DSCEngine__InvalidTokenLengthAndPriceFeedsLength();
        }
        for (uint256 i = 0; i < _tokens.length; i++) {
            s_priceFeeds[_tokens[i]] = _priceFeeds[i];
            s_collateralTokens.push(_tokens[i]);
        }
        i_dsc = StableCoin(_dsc);
    }

    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDSCMinted
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDSCMinted);
    }

    function depositCollateral(address _asset, uint256 _amount)
        public
        mustBeMoreThanZero(_amount)
        isAllowedToken(_asset)
        nonReentrant
    {
        s_collateralDeposits[msg.sender][_asset] += _amount;
        bool transferSuccess = IERC20(_asset).transferFrom(msg.sender, address(this), _amount);
        if (!transferSuccess) {
            revert DSCEngine__TransferFailed();
        }
        emit CollateralDeposited(msg.sender, _asset, _amount);
    }

    function redeemCollateralForDSC(address tokenCollateral, uint256 amountCollateral, uint256 amountDSCToBurn)
        external
    {
        burnDSC(amountDSCToBurn);
        redeemCollateral(tokenCollateral, amountCollateral);
    }

    function redeemCollateral(address tokenCollateral, uint256 amountCollateral)
        public
        mustBeMoreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(amountCollateral, tokenCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDSC(uint256 _amount) public mustBeMoreThanZero(_amount) {
        _burnDSC(_amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function mintDSC(uint256 _amount) public mustBeMoreThanZero(_amount) nonReentrant {
        s_amountDscMinted[msg.sender] += _amount;
        _revertIfHealthFactorIsBroken(msg.sender);

        bool success = i_dsc.mint(msg.sender, _amount);
        if (!success) {
            revert DSCEngine__MintingFailed();
        }
        emit DSCMinted(msg.sender, _amount);
    }

    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        mustBeMoreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingHealthFactor = _healthFactor(user);
        if (startingHealthFactor > MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOK();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUSD(collateral, debtToCover);

        uint256 bonusCollateral = tokenAmountFromDebtCovered * LIQUIDATION_BONUS / LIQUIDATION_PRECISION;

        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        _redeemCollateral(totalCollateralToRedeem, collateral, user, msg.sender);

        _burnDSC(debtToCover, user, msg.sender);

        uint256 endingUserHeathFactor = _healthFactor(user);
        if (endingUserHeathFactor <= startingHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view returns (uint256) {
        return _healthFactor(msg.sender);
    }

    function _getAccountInfo(address user) private view returns (uint256 totalDscMinted, uint256 collateralValueUSD) {
        totalDscMinted = s_amountDscMinted[user];
        collateralValueUSD = getCollateralValue(user);
    }

    function _redeemCollateral(uint256 amountCollateral, address tokenCollateral, address from, address to) private {
        s_collateralDeposits[from][tokenCollateral] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateral, amountCollateral);

        bool success = IERC20(tokenCollateral).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _burnDSC(uint256 _amount, address onBehalfOf, address dscFrom) private mustBeMoreThanZero(_amount) {
        s_amountDscMinted[onBehalfOf] -= _amount;

        bool success = i_dsc.transferFrom(dscFrom, address(this), _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(_amount);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueUSD) = _getAccountInfo(user);
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralRatioAdjusted = collateralValueUSD * LIQUIDATION_THRESHHOLD / LIQUIDATION_PRECISION;
        // $150 worth ETH -->  100 DSC
        // healthFactor becomes 150 *50 /100 = 75 and then 75 * 100 / 100 > 1

        return (collateralRatioAdjusted * PRECISION / totalDscMinted);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsBroken(healthFactor);
        }
    }

    function getCollateralValue(address user) public view returns (uint256 totalCollateralValueUSD) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposits[user][token];
            totalCollateralValueUSD += getUSDValue(token, amount);
        }
        return totalCollateralValueUSD;
    }

    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }

    function getTokenAmountFromUSD(address token, uint256 usdAmountinWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((usdAmountinWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getAccountInformation(address user)
        public
        view
        returns (uint256 totalDscMinted, uint256 collateralValueUSD)
    {
        return _getAccountInfo(user);
    }

    function getMinHealthFactor() public pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() public view returns (address[] memory collateralTokens) {
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address collateral) public view returns (uint256) {
        return s_collateralDeposits[user][collateral];
    }
}
