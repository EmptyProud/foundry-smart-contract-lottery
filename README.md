> Acknowledgment: I would like to extend my deepest gratitude to Patrick. His invaluable guidance and support were instrumental in the completion of this project. Without his help, this project would not have been possible. Additionally, I would like to acknowledge his significant contributions to the Ethereum development space, which have greatly benefited the community.

# Foundry Lottery Smart Contract

**This is a project that can be used to create a lottery with smart contract and deploy it onto your anvil chain or sepolia testnet. In addition, it provides scripting and testing.**

# Getting Started

## Requirements
- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - In terminal, run `git --version` , if you see a response like `git version x.x.x`, means you are on the right path.
- [foundry](https://getfoundry.sh/)
  - In terminal, run `forge --version`, if you see a response like `forge 0.2.0 (2a5400b 2023-03-16T00:05:26.396218Z)`, means you are on the right path.

## Quickstart
```
git clone https://github.com/EmptyProud/foundry-fund-me-f24
cd foundry-fund-me-f24
forge build
```

# Usage

## Installation of dependencies
```
make install
```
This install all the depencies that will be used in this project.

## Initialization of a local node
```
make anvil
```
This starts the anvil local Ethereum node with a block time of 90 seconds.

## Deployment 

### Deploying on local network
```
make deploy-anvil
```
To avoid failure of deployment, comments or removes all the account configuration in the broadcast sections of Script/ folder to avoid using foundry's default sender.

### Deploying on sepolia network

1. Setup environment variables
   
Set up your `SEPOLIA_RPC_URL`, `PRIVATE_KEY`, `ETHERSCAN_API_KEY` and  as environment variables. You may add them into a `.env` file.

- `SEPOLIA_RPC_URL`: The url of the sepolia testnet node you're working with. If you don't have one, try to get it from [Alchemy](https://www.alchemy.com/).
- `PRIVATE_KEY`: The private key of your account, use the account that you want it to send the transactions (deploy the smart contracts).
- `ETHERSCAN_API_KEY`: The api key of your Etherscan. You may get it from the [Etherscan API page](https://etherscan.io/myapikey) by after signed in your own account.

2. Get SepoliaETH

Head over to [Google Cloud Web3 faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia), [Alchemy faucet](https://www.alchemy.com/faucets/ethereum-sepolia), or [Chainlink faucet](https://faucets.chain.link/sepolia) to get some SepoliaETH.

3. Uncoment previous commented account configuration

If you have commented or removed all the account configuration in the broadcast sections of Script/ folder, you need replaces it back all the account configuration.

4. Remove console2.log

Remove all the console.log if u want to deploy it on sepolia, it could save u a lot of ETH sepolia

5. Deploy
```
make deploy-sepolia
```
This will setup a ChainlinkVRF Subscription for you. If you already have one, update it in the scripts/HelperConfig.s.sol file. It will also automatically add your contract as a consumer.

6. Register a Chainlink Automation Upkeep

Go to [Chainlink automation manager](https://automation.chain.link/) and register a new upkeep. Select `Custom Logic` as your automation's trigger mechanism. Once completed, your UI should be something like this:

![ChainlinkAutomation](./img/ChainlinkAutomation.png)

## Script
Once you have successfully deployed your raffle contract, you can the script.
### Using cast to enter your deployed Raffle smart contract (On Sepolia Network)
```
cast send <RAFFLE_CONTRACT_ADDRESS> "enterRaffle()" --value 0.1ether --private-key <PRIVATE_KEY> --rpc-url $SEPOLIA_RPC_URL
```
### Using cast to enter your deployed Raffle smart contract (On Local Network)
```
cast send <RAFFLE_CONTRACT_ADDRESS> "enterRaffle()" --value 0.1ether --private-key <ANVIL_ACC_PRIVATE_KEY>
```

## Test
We basically have four types of test:
1. Unit
2. Integration
3. Forked
4. Staging
This repo will only cover #1, #2, and #3.

### Testing on local network
```
make test
```
This will conduct testing on your local network.

### Testing on Sepolia network
```
make deploy-sepolia
```
This will conduct testing on the Sepolia network.

### Test Coverage
```
make coverage
```
This will print a summary of test coverage.

### Estimate gas
```
make snapshot
```
This will create a test file which includes estimated gas cost for testing.

## Formatting
```
forge fmt
```
This will format your code.