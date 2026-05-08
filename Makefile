-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make build      - Compile the contracts"
	@echo "  make test       - Run all tests"
	@echo "  make test-v     - Run tests with maximum verbosity"
	@echo "  make format     - Format code using forge fmt"
	@echo "  make clean      - Clean the repo"
	@echo "  make snapshot   - Create a gas snapshot"
	@echo "  make anvil      - Start a local Anvil node"

all: clean build test

build:
	forge build

test:
	forge test

test-v:
	forge test -vvvv

clean:
	forge clean

format:
	forge fmt

snapshot:
	forge snapshot

anvil:
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy-sepolia:
	forge script script/DeployDSC.s.sol:DeployDSC --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-anvil:
	forge script script/DeployDSC.s.sol:DeployDSC --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast