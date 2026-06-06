# Foundry DeFi Stablecoin

A decentralized, overcollateralized stablecoin protocol built with Solidity and Foundry.

This project is based on the architecture of modern DeFi lending and stablecoin systems, where users deposit collateral and mint a stable asset while maintaining a healthy collateralization ratio.

## Overview

The protocol allows users to:

* Deposit approved collateral assets
* Mint a decentralized stablecoin (DSC)
* Burn DSC to reduce debt
* Redeem collateral
* Maintain a healthy collateral position
* Participate in protocol liquidations when positions become undercollateralized

The goal of this project is to gain a deep understanding of:

* Solidity development
* Smart contract architecture
* DeFi protocols
* Stablecoin mechanics
* Foundry testing
* Security-focused development

---

## Project Architecture

### DecentralizedStableCoin.sol

ERC20 stablecoin contract responsible for:

* Minting DSC
* Burning DSC
* Ownership controls

### DSCEngine.sol

Core protocol logic responsible for:

* Collateral deposits
* Collateral redemption
* DSC minting
* DSC burning
* Health factor calculations
* Liquidation logic

### Price Feeds

Chainlink price feeds are used to determine collateral value and protocol health.

---

## Current Progress

### Completed

* Collateral Deposit System
* DSC Minting
* DSC Burning
* Collateral Redemption
* Health Factor Calculations
* Chainlink Price Feed Integration
* Unit Testing

### In Progress

* Liquidation Mechanics
* Additional Edge Case Testing
* Fuzz Testing
* Invariant Testing

### Future Improvements

* Frontend Dashboard
* Protocol Analytics
* Multi-Collateral Support
* Deployment Scripts for Testnets

---

## Tech Stack

* Solidity
* Foundry
* Chainlink Price Feeds
* OpenZeppelin Contracts

---

## Testing

Run the test suite:

```bash
forge test
```

Run tests with verbosity:

```bash
forge test -vvvv
```

Generate gas snapshots:

```bash
forge snapshot
```

---

## Learning Objectives

This repository serves as a practical study project for:

* Advanced Solidity
* Smart Contract Security
* DeFi Protocol Design
* Stablecoin Systems
* Foundry Development Workflow

---

## Repository Status

This project is actively being developed and updated as part of my Web3 and smart contract engineering journey.

New features, tests, and improvements are added regularly.

---

## Author

Pramod Khadka


