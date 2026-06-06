// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin
// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
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
// view & pure functions

pragma solidity 0.8.19;

import {ERC20Burnable,ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/*
@title:DecentralizedStableCoin
@author: Pramod Khadka 
@collateral: WETH and WBTC
@minting: Algorithmic
* this is the contract meant to be governed by DSCEngine. This contract s just ERC"= implementation of our stabecoin system.
*/
  contract DecentralizedStableCoin is ERC20Burnable,Ownable {

    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error  DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC"){}


    function  burn(uint256 _amount) public override onlyOwner {
        //The amount burnt must not be less than zero
        //The amount burnt must not be more than the user's balance
        //The burn function should only be callable by the owner of the contract, which is the DSCEngine contract   
        //The burn function should decrease the total supply of the token by the amount burnt
        uint256 balance = balanceOf(msg.sender);
        //
        if(_amount <= 0){
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if(balance < _amount){
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
        }   

        function mint(address _to, uint256 _amount) external onlyOwner returns(bool){
            //The amount minted must not be less than zero
            //The mint function should only be callable by the owner of the contract, which is the
    // DSCEngine contract
            //The mint function should increase the total supply of the token by the amount minted
            if(_to == address(0)){
                revert DecentralizedStableCoin__NotZeroAddress();
            }
            if(_amount <= 0){
                revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
            }
            _mint(_to,_amount);
            return true;
        }         
    
    
    
    
    
    
      }
