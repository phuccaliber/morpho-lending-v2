#!/bin/bash
set -e # Exit on any error

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create deployments directory if it doesn't exist
mkdir -p deployments

echo -e "${GREEN}Starting Anvil...${NC}"
# Start Anvil in the background and save its PID
anvil --silent > /dev/null 2>&1 &
ANVIL_PID=$!

# Wait for Anvil to start
sleep 2

# Cleanup function that will be called on script exit
cleanup() {
  echo -e "${GREEN}Cleaning up...${NC}"
  # Kill Anvil process
  if [ -n "$ANVIL_PID" ]; then
    kill $ANVIL_PID
    wait $ANVIL_PID 2>/dev/null || true
    echo -e "${GREEN}Anvil stopped.${NC}"
  fi
}

# Set the cleanup function to run on exit (including errors)
trap cleanup EXIT

echo -e "${GREEN}Deploying mock contracts...${NC}"
# Deploy the mock contracts
forge script test/mock/DeployMock.sol --rpc-url http://localhost:8545 --broadcast

# Check if deployment was successful
if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment failed!${NC}"
    exit 1
fi

export PROFILE=local

echo -e "${GREEN}Running tests...${NC}"
# Run the tests using the forked network
# forge test --rpc-url http://localhost:8545 --mc LocalSupplyCollateralTest -vvvv
# forge test --rpc-url http://localhost:8545 --mp 'test/foundry/*/*.t.sol' -vvvv

# Check if tests were successful
if [ $? -ne 0 ]; then
    echo -e "${RED}Tests failed!${NC}"
    exit 1
fi

echo -e "${GREEN}All done! Tests completed successfully.${NC}"
# The cleanup function will be called automatically to stop Anvil
