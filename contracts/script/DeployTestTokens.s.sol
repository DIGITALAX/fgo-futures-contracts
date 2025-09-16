// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "../src/TestERC20.sol";
import "../src/TestERC721.sol";

contract DeployTestTokens is Script {
    function run() external {
        console.log("=== Test Tokens Deployment ===");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast();

        console.log("\n--- Step 1: Deploying Test ERC20 (MONA) ---");
        console.log("Deploying TestERC20...");
        new TestERC20(
            "MONA Token",
            "MONA", 
            18,
            1000000000,
            msg.sender
        );

        console.log("\n--- Step 2: Deploying Test ERC721 (Qualifying NFT) ---");
        console.log("Deploying TestERC721...");
        new TestERC721(
            "FGO Qualifying NFT",
            "FGONFT",
            "https://api.fgo.futures/nft/",
            msg.sender
        );

        vm.stopBroadcast();

        console.log("\n--- DEPLOYMENT COMPLETE ---");
        console.log(
            "IMPORTANT: The real contract addresses will be in the broadcast JSON file:"
        );
        console.log(
            "Path:",
            string.concat(
                "broadcast/DeployTestTokens.s.sol/",
                vm.toString(block.chainid),
                "/run-latest.json"
            )
        );
        console.log("Look for 'contractAddress' fields in the receipts array");
        console.log("Order: TestERC20/MONA (receipts[0]), TestERC721/FGONFT (receipts[1])");
        console.log("=== Test Tokens Deployment Complete ===");
    }
}