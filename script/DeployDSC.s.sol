//SPDX-license-Identifier : MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";



  contract DeployDSC is Script{

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

function run() external returns(DecentralizedStableCoin, DSCEngine,HelperConfig){
    HelperConfig config = new HelperConfig();
    // creates a configuration contract that stores network-specific addresses


    (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerkey)= config.activeNetworkConfig();
    tokenAddresses =[weth,wbtc];
    priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

    vm.startBroadcast();
    // deploys the DSC stablecoin contract
    DecentralizedStableCoin dsc = new DecentralizedStableCoin();
    // deploys the DSCEngine contract, passing in the token and price feed addresses, as well as the address of the DSC contract
    DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    dsc.transferOwnership(address(engine));
    vm.stopBroadcast();
    return (dsc,engine,config);
    
    
    
    
    
    }



  }
