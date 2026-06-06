// SPDX-License-Identifier : MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions



pragma solidity ^0.8.19;

import { DecentralizedStableCoin } from "./DecentralizedStableCoin.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/*
 * @title DSCEngine
 * @author Patrick Collins
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system*/

contract DSCEngine is ReentrancyGuard{
///////////////////
    // Errors
    ///////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();   
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();       
  
    error DSCEngine__HealthFactorIsBroken(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();



    ///////////////////
    // state variables
    ///////////////////
    mapping(address token=> address priceFeed) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_dsc;
    mapping(address user=> mapping(address token=> uint256 amount))private s_collateralDeposited;
    mapping(address user=> uint256 amountDscMinted) private s_DSCMinted;
    address[]private s_collateralTokens;
    //address private immutable i_ethUsdPriceFeed;
    //address private immutable i_btcUsdPriceFeed;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; 
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 150; // 150%
    uint256 private constant LIQUIDATION_PRECISION = 100; // 100%   
    uint256 private constant MIN_HEALTH_FACTOR = 1e18; // 1.0 in 18 decimals
   uint256 private constant LIQUIDATION_BONUS = 10; // 10% bonus for liquidators

// Chainlink price feeds have 8 decimals, but our system uses 18 decimals, so we need




///////////////////
    // events
    ///////////////////
event CollateralDeposited(address indexed user,address indexed token, uint256  indexed amount); // whenever collateral is deposited, record the user, token, and amount.
event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount); // whenever collateral is redeemed, record the user, token, and amount.
///////////////////
    // Modifiers
    ///////////////////
 modifier moreThanZero(uint256 amount){
    if(amount == 0){
        revert DSCEngine__NeedsMoreThanZero();
    }
    _;
 }
 modifier isAllowedToken(address token){
    if(s_priceFeeds[token] == address(0)){
        revert DSCEngine__NotAllowedToken();
    }
    _;
 }
 ///////////////////////////
//    Functions  //
///////////////////////////
constructor(address[] memory tokenAddresses,address[] memory priceFeedAddresses, address dscAddress){
    if(tokenAddresses.length != priceFeedAddresses.length){
        revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    }
    for(uint256 i = 0; i < tokenAddresses.length; i++){
        s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        s_collateralTokens.push(tokenAddresses[i]);
    }
    // We want to make sure the price feeds are set up correctly, so we can test the system with WETH and WBTC as collateral
    i_dsc = DecentralizedStableCoin(dscAddress);
   
}
///////////////////////////
//   External Functions  //
///////////////////////////
/*
*@param tokenCollateralAddress: the ERC20 token address of the collateral you are depositing
*@param amountCollateral: the amount of collateral you are depositing
*@param amountDscToMint: the amount of DSC you want to mint
*@notice this function allows users to deposit collateral and mint DSC in one transaction. This is more
efficient than calling the depositCollateral and mintDsc functions separately.
*/

function depoistCollateralAndMintDsc(address tokenCollateralAddress, uint256 amountCollateral,uint256 amountDscToMint) external {
depositCollateral(tokenCollateralAddress, amountCollateral);
mintDsc(amountDscToMint);
}

 
function reedemCollateralAndBurnDsc() external {}

function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public moreThanZero(amountCollateral) nonReentrant isAllowedToken(tokenCollateralAddress){
 _redeemCollateral(tokenCollateralAddress, msg.sender, msg.sender, amountCollateral);
 _revertifHealthFactorIsBroken(msg.sender);
}
/*
*@param tokenCollateralAddress: the ERC20 token address of the collateral you are redeeming
*@param amountCollateral: the amount of collateral you are redeeming
*@param amountDscToBurn: the amount of DSC you want to burn
*@notice this function allows users to redeem collateral and burn DSC in one transaction. This is more efficient than calling the redeemCollateral and burnDsc functions separately.
*/
function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn) external  moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress)
{
    _burnDsc(amountDscToBurn, msg.sender, msg.sender);
    _redeemCollateral(tokenCollateralAddress,  msg.sender, msg.sender, amountCollateral);
    _revertifHealthFactorIsBroken(msg.sender);
}


function burnDsc(uint256 amount) external moreThanZero(amount){
    // The amount of DSC to burn must be more than zero
    // The user must have enough DSC minted to burn the desired amount
    // The function should update the user's total DSC minted in the system
    // The function should emit a DscBurned event
//s_DSCMinted[msg.sender]-= amount; // update the user's total DSC minted in the system
//bool success = i_dsc.transferFrom(msg.sender, address(this), amount);// transfer the DSC from the user to the DSCEngine contract
// i_dsc: the DSC contract, which has a mint function that allows the DSCEngine to mint new DSC tokens and a transferFrom function that allows users to transfer their DSC tokens to the DSCEngine contract when they want to burn them.
// msg.sender: the user burning DSC, address(this): the DSCEngine contract; amount: number of tokens to transfer.
//if(!success){
    revert DSCEngine__TransferFailed();
//}
_burnDsc(amount, msg.sender, msg.sender);
_revertifHealthFactorIsBroken(msg.sender);
}

/*
*@pram collateral The erc20 collateral address to liquidate from the user
*@param user the user who has broken the health factor. Their _healthfactor should be below MIN_HEALTH_FACTOR
*@param debtToCover The amount of DSC you want to burn to improve the user health factor. This will also determine how much collateral you will receive from the user. The more DSC you burn, the more collateral you will receive.
@notice this function allows users to liquidate other users who have broken the health factor. This is an important function to maintain the stability of the system. If a user's health factor is below the minimum, they can be liquidated by other users. 
The liquidator will burn their DSC to reduce the debt of the user being liquidated, and in return, they will receive a portion of the user's collateral. The amount of collateral received is determined by the amount of DSC burned and the current price of the collateral.
@notice you will get a liquidation bonus for performing a liquidation. This is an incentive for users to participate in the liquidation process and help maintain the stability of the system. 
The liquidation bonus is a percentage of the collateral received from the user being liquidated. For example, if the liquidation bonus is 5% and you receive $100 worth of collateral from the user being liquidated, you will receive an additional $5 worth of collateral as a bonus.

*/
function liquidate( address collateral, address user, uint256 debtToCover) external 
moreThanZero (debtToCover) 
nonReentrant
{
    // need to check health factor of the user
    uint256 startingUserHealthFactor = _healthFactor(user);
    if(startingUserHealthFactor > MIN_HEALTH_FACTOR){
        revert DSCEngine__HealthFactorOk();
    }

    uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);

    
    uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

   uint256 totalCollateralRedeemed = tokenAmountFromDebtCovered + bonusCollateral;// total Collateral to the liquidator


   _redeemCollateral(user, msg.sender, collateral, totalCollateralRedeemed); // move collateral form the unhealthy user to the liquidator

    _burnDsc(debtToCover, user, msg.sender); // burn the liquidator dsc and reduce the users debt

   uint256 endingUserHealthFactor = _healthFactor(user);
   if(endingUserHealthFactor <= startingUserHealthFactor){
    revert DSCEngine__HealthFactorNotImproved();
}
_revertifHealthFactorIsBroken(msg.sender); // ensure the liquidator remains healthy after liquidation

}


function getAccountCollateralValue() external view returns(uint256){}
function getAccountDscValue() external view returns(uint256){}
function getAccountHealthFactor() external view returns(uint256){}
//////////////////////////////////////////
//   public functions  //
//////////////////////////////////////////

/*
*@param amountDscToMint: the amount of dsc you want to mint
* you can only mint DSC if you have eniugh collateral
*/

function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant{
    // The amount of DSC to mint must be more than zero
    // The user must have enough collateral to mint the desired amount of DSC
    // The function should update the user's total DSC minted in the system
    // The function should emit a DscMinted event
    //s_DSCMinted represent How much DSC debt the user currently owes which is already minted and the amountDscToMint represent how much dsc want to mint .
    // 
s_DSCMinted[msg.sender] += amountDscToMint;
// after minting this <dsc. is the user still safe?
// Revert if minting makes the position undercollateralized.
_revertifHealthFactorIsBroken(msg.sender);
bool minted= i_dsc.mint(msg.sender, amountDscToMint);
if(!minted){
    revert DSCEngine__MintFailed();
}
}

function depositCollateral(address tokenCollateralAddress,uint256 amountCollateral) public moreThanZero(amountCollateral)isAllowedToken(tokenCollateralAddress)nonReentrant {
    // The amount of collateral deposited must be more than zero
    // The token used as collateral must be allowed by the system (WETH or WBTC)
    // The function should update the user's total collateral value in the system
    // The function should emit a CollateralDeposited event
s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
emit CollateralDeposited(msg.sender, tokenCollateralAddress,amountCollateral);
// transfer the user weth to the dscengine.
// we use transferfrom because you cannot take my tokens unless i approve you first.
bool success= IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
if(!success){
    revert DSCEngine__TransferFailed();
}
}
 //////////////////////////////////////////
//   Private & Internal View Functions  //
//////////////////////////////////////////


/*
 * Returns how close to liquidation a user is
 * If a user goes below 1, then they can be liquidated.
*/

 function _healthFactor(address user) private view returns(uint256){
(uint256 totalDscMinted, uint256 collateralValueInUsd)= _getAccountInformation(user);
uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
 return (collateralAdjustedForThreshold* PRECISION)/ totalDscMinted;
 }
 
 function _revertifHealthFactorIsBroken(address user) internal view{
    uint256 userHealthFactor = _healthFactor(user);
    if(userHealthFactor < MIN_HEALTH_FACTOR){
        revert DSCEngine__HealthFactorIsBroken(userHealthFactor);
     }
    }
    function _getAccountInformation(address user) internal view returns(uint256 totalDscMinted, uint256 collateralValueInUsd){
 
    totalDscMinted = s_DSCMinted[user];
    collateralValueInUsd = getAccountCollateralValue(user);
    // GETACCOUNTCOLLATERALVALUE is this function calculates the total USD value of all collateral deposited by the user.-
 }


 //////////////////////////////////////////
//   Private  Functions  //
//////////////////////////////////////////
 function _redeemCollateral (address from, address to, address tokenCollateralAddress, uint256 amountCollateral) private {
    s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
    emit CollateralRedeemed(from,to, tokenCollateralAddress, amountCollateral);

    bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
    if(!success){
        revert DSCEngine__TransferFailed();
    }
 }
/* 
*@dev Low-level internal function , do not call unless the function calling it is 
*checking for health factors being broken
*/
 function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
    s_DSCMinted[onBehalfOf] -= amountDscToBurn;// update the user's total DSC minted in the system and reduce the user outstanding Dsc debt.anonymous
    bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);// transfer the DSC from the user to the DSCEngine contract
    //this conditional is hypothetically unreachable because the transferFrom function will return false if the user does not have enough DSC to burn, but we will include it for safety.
    if(!success){
        revert DSCEngine__TransferFailed();
    }
    i_dsc.burn(amountDscToBurn); // Permanently remove the DSC tokens form circulation.
 }


//////////////////////////////////////////
//   Public & External View Functions   //
//////////////////////////////////////////

// this function takes in an amount of a collateral token and returns the equivalent USD value of that collateral using the price feed for that token. It does this by getting the latest price from the Chainlink price feed, adjusting for decimals, and then multiplying by the amount of collateral to get the total USD value.
function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256){
    AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
    (,int256 price,,,) = priceFeed.latestRoundData();
    // Chainlink price feeds have 8 decimals, but our system uses 18 decimals, so we need to adjust the price accordingly 
    return(usdAmountInWei * PRECISION)/ (uint256(price)* ADDITIONAL_FEED_PRECISION);
}

function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUsd){
 for(uint256 i=0; i<s_collateralTokens.length; i++){
    address token = s_collateralTokens[i];
    uint256 amount= s_collateralDeposited[user][token];
    totalCollateralValueInUsd += getUsdValue(token, amount);
 }
 return totalCollateralValueInUsd;
}
 // this function calculates the total USD value of all collateral deposited by the user. It iterates through all the collateral tokens, gets the amount of each token deposited by the user, converts that amount to USD 
 //using the getUsdValue function, and sums it up to get the total
function getUsdValue(address token, uint256 amount) public view returns(uint256){
    AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
(,int256 price,,,) = priceFeed.latestRoundData();

// Chainlink price feeds have 8 decimals, but our system uses 18 decimals, so we need to adjust the price accordingly 
return((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
}

function getAccountInformation(address user) external view returns(uint256 totalDscMinted, uint256 collateralValueInUsd){
    (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
}












}
