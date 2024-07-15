-include .env

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
DEFAULT_ZKSYNC_LOCAL_KEY := 0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1


deploy:
	@forge script script/DeployDontBridge.s.sol:DeployDontBridge $(NETWORK_ARGS)

# NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

NETWORK_ARGS := --rpc-url $(ARBI_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ARBISCAN_API_KEY) -vvvv

OP_NETWORK_ARGS := --rpc-url $(OP_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(OPTISCAN_API_KEY) -vvvv

ifeq ($(findstring --network opt ,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(OP_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(OPTISCAN_API_KEY) -vvvv
endif


deploy-op:
	@forge script script/DeployDontBridge.s.sol:DeployDontBridge $(OP_NETWORK_ARGS)

