//SPDX-license-Identifier : MIT

pragma solidity 0.8.19;
import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import { MockV3Aggregator } from "../test/mocks/MockV3Aggregator.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

    contract HelperConfig is Script{
        NetworkConfig public activeNetworkConfig;
 uint8 public constant DECIMALS = 8;
 int256 public constant ETH_USD_PRICE = 2000e8;
 int256 public constant BTC_USD_PRICE = 1000e8;
uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a3ce75935abf66e9cbd8c93e870b07029bfcdb2;
        struct NetworkConfig{
            address wethUsdPriceFeed;
            address wbtcUsdPriceFeed;
            address weth;
            address wbtc;
            uint256 deployerKey;

        }
      
         constructor(){
            if(block.chainid == 11155111){
                activeNetworkConfig = getSepoliaEthConfig();
            }else{
                activeNetworkConfig = getOrCreateAnvilEthConfig();
            }

         }

         function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
        wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
        wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
        weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
        wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
        deployerKey: vm.envUint("PRIVATE_KEY")
    });
}
function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig){
// check if we have the env variable, if not then we deploy mocks
// check if the activeNetworkconfig has one of our token price feed addresses, if it does then we can assume we are on a local anvil chain and we can use the existing config
if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
    return activeNetworkConfig; 
}
vm.startBroadcast();
// deploy mocks
MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
//ERC20Mock wethMock = NEW ERC20Mock("WETH","WETH", msg.sender, 1000e8);
ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e18);

MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS,BTC_USD_PRICE);
//ERC20Mock wbtcMock = NEW ERC20Mock("WBTC","WBTC", msg.sender, 1000e18);
ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
vm.stopBroadcast();
anvilNetworkConfig = NetworkConfig({
  wethUsdPriceFeed: address(ethUsdPriceFeed), // ETH / USD
  weth: address(wethMock),
  wbtcUsdPriceFeed: address(btcUsdPriceFeed),
  wbtc: address(wbtcMock),
  deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
});
}
    }