// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
import {Morpho} from "../../lib/metamorpho-v1.1/lib/morpho-blue/src/Morpho.sol";

contract DeployMock is Script {
    using stdJson for string;

    function run() external {
        uint256 deployerPrivateKey;

        // Check if PRIVATE_KEY is explicitly set
        if (vm.envExists("MOCK_PRIVATE_KEY")) {
            deployerPrivateKey = vm.envUint("MOCK_PRIVATE_KEY");
            console.log("Using provided private key");
        } else {
            // Use the first Anvil default account's private key
            // This is the well-known private key for the first account in Anvil
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
            console.log("Using default Anvil account #0");
        }

        // Start broadcast with the private key
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Morpho contract
        address owner = vm.addr(deployerPrivateKey);
        Morpho morpho = new Morpho(owner);

        // Stop broadcast
        vm.stopBroadcast();

        // Create JSON with deployment info
        string memory json = vm.serializeAddress(
            "",
            "address",
            address(morpho)
        );
        json = vm.serializeAddress("", "owner", owner);
        string memory path = string.concat(
            vm.projectRoot(),
            "/deployments/morpho.json"
        );
        vm.writeJson(json, path);

        console.log("Morpho deployed at:", address(morpho));
        console.log("Owner set to:", owner);
    }
}
