//SPDX_License-Identifier:MIT
  
  pragma solidity ^0.8.19;


import {Test,console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import{DeployDSC} from "../../script/DeployDSC.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";


contract DSCEngineTest is Test {

    DeployDSC public  deployer;
    DecentralizedStableCoin  public dsc;
    DSCEngine public dsce;
    HelperConfig public config;
    address public weth;
    address public wbtc;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    uint256 deployerKey;


 address public user = makeAddr("user");
 uint256 public constant AMOUNT_COLLATERAL = 10 ether;
  uint256 public constant STARTING_USER_BALANCE = 10 ether;

     function setUp() public {
        // deploys the DSC stablecoin and DSCEngine contracts using the DeployDSC scriptwha
        deployer = new DeployDSC();
        (dsc,dsce,config)= deployer.run();
       // (ethUsdPriceFeed,btcUsdPriceFeed,weth,wbtc)= config.activeNetworkConfig();
       (
    ethUsdPriceFeed,
    btcUsdPriceFeed,
    weth,
    wbtc,
    deployerKey
)
 = config.activeNetworkConfig();
   
        if (block.chainid == 31_337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }
        // Should we put our integration tests here?
        // else {
        //     user = vm.addr(deployerKey);
        //     ERC20Mock mockErc = new ERC20Mock("MOCK", "MOCK", user, 100e18);
        //     MockV3Aggregator aggregatorMock = new MockV3Aggregator(
        //         helperConfig.DECIMALS(),
        //         helperConfig.ETH_USD_PRICE()
        //     );
        //     vm.etch(weth, address(mockErc).code);
        //     vm.etch(wbtc, address(mockErc).code);
        //     vm.etch(ethUsdPriceFeed, address(aggregatorMock).code);
        //     vm.etch(btcUsdPriceFeed, address(aggregatorMock).code);
        // }
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
    
     }
////////////////
// Constructor Tests //
/////////////////


// The constructor of the DSCEngine contract should set the token and price feed addresses correctly. 
//We can test this by deploying the contract and then checking that the addresses are stored correctly in the contract's state variables.
// we push the token and priceFeedAddresses because the array are empty in the test contract, and we need to have some values in them to test the constructor logic.
address[]public tokenAddresses;
address[] public priceFeedAddresses;

 function testRevertIfTokenLengthDoesntMatchPriceFeeds() public {
  tokenAddresses.push(weth);
  priceFeedAddresses.push(ethUsdPriceFeed);
  priceFeedAddresses.push(btcUsdPriceFeed);

  vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
  // deploys the DSCEngine contract with mismatched token and price feed addresses, which should cause the constructor to revert with the expected error message.
  // testing the constructor logic, Deploy with new
  new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
 }






////////////////
// Price Tests //
/////////////////

 //eth -> usd
function testGetUsdValue() public {
  uint256 ethAmount = 15e18;
  // 15e18 ETH * 2000/ETH = $30000e18;
  uint256 expectedUsd = 30_000e18;
  uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
  assertEq(actualUsd, expectedUsd);
}
// usd-> eth
// this function tests the getTokenAmountFromUsd function of the DSCEngine contract. It checks that when we input a USD amount, we get the correct equivalent amount of the collateral token (in this case, WETH) based on the current price feed data. The expected WETH amount is calculated based on the price feed for WETH/USD, and we assert that the actual amount returned by the function matches our expected value.
function testGetTokenAmountFromUsd() public{
  uint256 expectedWeth = 0.05 ether;
  // to calculate the expected WETH amount, we take the USD amount (100 USD) and divide it by the price of WETH in USD (2000 USD/WETH), which gives us 0.05 WETH. We then convert that to wei by multiplying by 1e18, since the getTokenAmountFromUsd function returns the amount in wei.
  uint256 amountWeth = dsce.getTokenAmountFromUsd(weth, 100 ether);
  assertEq(amountWeth, expectedWeth);
}

////////////////
// depositCollateral Tests //
/////////////////


//Deploy a token whose transferFrom always fails, configure DSCEngine to accept it, 
//attempt a deposit, and verify DSCEngine reverts with DSCEngine__TransferFailed.
// verify depositcollateral reverts when the collateral token transfer fails
 function testRevertsIfTransferFromFails() public {
  // save the current caller address to use as the contract deployer
        address owner = msg.sender;
        vm.prank(owner); // make the next contract deployment execute as the owner
        MockFailedTransferFrom mockCollateralToken = new MockFailedTransferFrom();// Deploy a mock token that always returns false from transferFrom()
        tokenAddresses = [address(mockCollateralToken)];// makes the mock token the only allowed collateral token
        feedAddresses = [ethUsdPriceFeed];
        // DSCEngine receives the third parameter as dscAddress, not the tokenAddress used as collateral.
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(dsc)); // // Deploy a DSCEngine configured to accept the mock token.
        mockCollateralToken.mint(user, amountCollateral); // give the user collateral tokens for testing
        vm.startPrank(user);
        ERC20Mock(address(mockCollateralToken)).approve(address(mockDsce), amountCollateral);
        // Act / Assert
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDsce.depositCollateral(address(mockCollateralToken), amountCollateral);
        vm.stopPrank();
    }


 function testRevertsIfCollateralIsZero() public {
vm.startPrank(user);
// approves the DSCEngine contract to spend the user's collateral tokens, which is necessary before calling the depositCollateral function.
// we approve the collateral because the depositCollateral function will try to transfer the collateral from the user's account to the DSCEngine contract, and if we haven't approved it, the transfer will fail and the function will revert.
ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
dsce.depositCollateral(weth,0);
vm.stopPrank();
 } 


// users can only deposit approved collateral tokens.
// if a user tries to deposit a token that is not approved as collateral, the function should revert with the expected error message.
function testRevertsWithUnapprovedCollateral() public {
  ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", user, AMOUNT_COLLATERAL);
  vm.startPrank(user);
  vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
  dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
  vm.stopPrank();
}

//"Before running the test, approve and deposit collateral so the test
// starts with a user who already has collateral in DSCEngine."
// the depositCollateral weth, amountCollateral because on our function depositCollateral we have passed this parameter
modifier depositedCollateral(){
  vm.startPrank(user);
  ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL); // allows DSCEngine to spend WETH
  dsce.depositCollateral(weth, AMOUNT_COLLATERAL);// deposit collateral
  vm.stopPrank();
  _;
}
function testCanDepositCollateralAndGetAccountInfo() public  depositedCollateral{
  // heyDscEngine, give me the total amount of DSC minted and the total value of my collateral in USD after I have deposited collateral.
(uint256 totalDscMinted, uint256 collateralValueInUsd)= dsce.getAccountInformation(user);

uint256 expectedTotalDscMinted = 0;
// convert usd value back into ether value, because the collateral is in ether, and we want to compare it to the amount of collateral we deposited.
// we use the getTokenAmountFromUsd function to convert the collateral value in USD back into the amount of collateral tokens, which should be equal to the amount of collateral we deposited.
uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
assertEq(totalDscMinted, expectedTotalDscMinted);
assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);

}
// Depositing collateral does Not automatically mint DSC
function testCanDepositCollateralWithoutMinting() public depositedCollateral{
  uint256 userBalance = dsc.balanceOf(user);
  assertEq(userBalance,0);
}
///////////////////////////////////////
  // depositCollateralAndMintDsc Tests //
    /////////////////////////////////////
 
 function testRevertsIfMintedDscBreaksHealthFactor() public {
  (,int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
  amountToMint = (amountCollateral* (uint256(price)* dsce.getadditionalFeedPrecision()))/ dsce.getPrecision(); // calculate a dsc amount large enough to break the health factor
  vm.startPrank(user);

  ERC20Mock(weth).approve(address(dsce), amountCollateral);

  uint256 expectedHealthFactor = dsce.calculatehealthFactor(amountToMint, 
  dsce.getusdValue(weth,amountCollateral));

  vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 
  expectedHealthFactor));
  dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
  vm.stopPrank();
 }

modifier depositedCollateralAndMintedDsc(){
  vm.startPrank(user);
  ERC20Mock(weth).approve(address(dsce), amountCollateral);
  dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
  vm.stopPrank();
  _;
}
// the modifier have checked user deposited collateral and user minted Dsc
// the tests ask Did the user actually receive the Dsc that was minted?
function testCanMintWithDepositedCollateral () pubic depositedCollateralAndMintedDSC {
  uint256 userBalance = dsc.balanceOf(user);
  assertEq(userBalance, anountToMint);
}

//////////////////////////////////////
///MintDsc Test//////////////////
//////////////////////////////////////


// this test needs its own custo, setup
// what if the DSc token contract fails to mint?
// will DSCEngine handle it correctly?
 function testRevertsIfMintFails() public {
  //Arrange -setup
  MockFailedMintDsc mockDsc = new MockFailedMintDsc();// Deploy a mock DSC token whose mint function always fails.
  tokenAddresses = [weth];// Configure weth as the allowed collateral token
  feedAddresses = [ethUsdPriceFeed];
  address owner= msg.sender;
  vm.prank(owner);
  DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));// deploys DSCEngine using the mock DSC token
  mockDsc.transferOwnership(address(mockDsce)); // Give  DSCEngine permission to mint DSC
  //Arrange - User
  vm.startPrank(user);
  ERC20Mock(weth).approve(address(mockDsce), amountCollateral);

  vm.expectRevert (DSCEngine.DSCEngine__MintFailed.selector);
  mockDsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
  vm.stopPrank();
 }


 function testRevertsIfMintAmountIsZero( ) public {
   vm.startPrank(user);
   ERC20Mock(weth).approve(address(dsce), amountCollateral);
   //dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
   vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanzero.selector);
   dsce.mintDSc(0);
   vm.stopPrank();
 }

function testRevertsIfMintAmountBreaksHealthFactor() public depositedCollateral{   
(,int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
amountToMint = (amountCollateral * (uint256(price)* dsce.getAdditionalFeedPrecision()))/ dsce.getPrecision();

vm.startPrank(user);
uint256 expectedHealthFactor = 
dsce.calculateHealthFactor(amountToMint, dsce.getUsdValue(weth, amountCollateral));
vm.expectRevert(abi.encodeWithSelector
(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
dsce.mintDsc(amountToMint);
vm.stopPrank();
}
function testCanMintDsc() public depositedCollateral {
        vm.prank(user);
        dsce.mintDsc(amountToMint);

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, amountToMint); 
      }

function testCannotMintWithoutDepositingCollateral() public depositedCollateral {
  vm.startPrank(user);
  // Do NOT deposit collateral; do NOT approve anything.
  // Try to mint — should revert because health factor will be broken.
  // With 0 collateral, the health factor will be 0
   uint256 expectedHealthFactor = dsce.calculateHealthfactor(amountToMint ,0);
   vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthfactor));
   dsce.mintDsc(amountToMint);
   vm.stopPrank();
}

////////////////////////////
////burnDsc Test//////////////////////
////////////////////////////


function testRevertsIfBurnAmountIsZero() public {
    //When testing burnDsc(0), the function reverts at the moreThanZero modifier before any burn logic executes, 
    //so collateral deposits, approvals, and minted DSC are unnecessary setup.
    ////ERC20Mock(weth).approve(address(dsce), amountCollateral);
    //dsce.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
    vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
    dsce.burnDsc(0);
}

function testCantBurnMoreThanUserHas() public {
    vm.prank(user);
    vm.expectRevert(
    DSCEngine.DSCEngine__TransferFailed.selector);
    dsce.burnDsc(1);
}
   function testCanBurnDsc() public depositedCollateralAndMintedDsc {
    vm.startPrank(user);
    dsc.approve(address(dsce), amountToMint);// Allow DSCEngine to transfer the users DSC.
    dsce.burnDsc(amountToMint); // burn all DSC owned by the user
    vm.stopPrank();

    uint256 userBalance = dsc.balanceOf(user);
    assertEq(userBalance, 0);// verify all DSC was burned
   }

///////////////////////////////////
    // redeemCollateral Tests //
    //////////////////////////////////


}
