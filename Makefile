-include .env

.PHONY: all test deploy

build :; forge build

test :; forge test

install :; forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit && forge install foundry-rs/forge-std@v1.8.2 --no-commit

deploy-sepolia :
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account myaccount --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 90

deploy-anvil :
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --sender $(ANVIL_SENDER_ADDRESS) --broadcast -vvvv

coverage-report :; forge coverage --report debug > coverage.txt