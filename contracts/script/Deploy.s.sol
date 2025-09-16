// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import "../src/FGOFuturesAccessControl.sol";
import "../src/FGOFuturesContract.sol";
import "../src/FGOFuturesEscrow.sol";
import "../src/FGOFuturesTrading.sol";
import "../src/FGOFuturesMEV.sol";

contract DeployFGOFutures is Script {
    using stdJson for string;

    struct FuturesContracts {
        FGOFuturesAccessControl accessControl;
        FGOFuturesEscrow escrow;
        FGOFuturesContract futuresContract;
        FGOFuturesTrading trading;
        FGOFuturesMEV mev;
    }

    function run() external {
        console.log("=== FGO Futures Deployment ===");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);

        address monaToken = 0x6968105460f67c3BF751bE7C15f92F5286Fd0CE5;
        address qualifyingNFT = 0x959e104E1a4dB6317fA58F8295F586e1A978c297;
        address lpTreasury = msg.sender;
        address protocolTreasury = msg.sender;
        
        address[] memory validERC721Tokens = new address[](1);
        validERC721Tokens[0] = qualifyingNFT;
        
        uint256 protocolFeeBPS = 100;
        uint256 lpFeeBPS = 50;
        uint256 minStakeAmount = 10000 * 10**18;
        uint256 maxSettlementDelay = 3600;
        uint256 slashPercentageBPS = 1000;
        string memory baseURI = "https://api.fgo.futures/metadata/{id}";

        vm.startBroadcast();

        console.log("\n--- Step 1: Deploying Access Control ---");
        console.log("Deploying FGOFuturesAccessControl...");
        FGOFuturesAccessControl accessControl = new FGOFuturesAccessControl(msg.sender, monaToken);

        console.log("\n--- Step 2: Deploying Escrow ---");
        console.log("Deploying FGOFuturesEscrow...");
        FGOFuturesEscrow escrow = new FGOFuturesEscrow(address(accessControl));

        console.log("\n--- Step 3: Deploying Futures Contract ---");
        console.log("Deploying FGOFuturesContract...");
        FGOFuturesContract futuresContract = new FGOFuturesContract(
            address(accessControl),
            address(escrow),
            validERC721Tokens
        );

        console.log("\n--- Step 4: Deploying Trading ---");
        console.log("Deploying FGOFuturesTrading...");
        FGOFuturesTrading trading = new FGOFuturesTrading(
            address(accessControl),
            address(futuresContract),
            address(escrow),
            lpTreasury,
            protocolTreasury,
            protocolFeeBPS,
            lpFeeBPS,
            baseURI
        );

        console.log("\n--- Step 5: Deploying MEV ---");
        console.log("Deploying FGOFuturesMEV...");
        FGOFuturesMEV mev = new FGOFuturesMEV(
            address(accessControl),
            address(futuresContract),
            address(escrow),
            address(trading),
            minStakeAmount,
            maxSettlementDelay,
            slashPercentageBPS
        );

        console.log("\n--- Step 6: Setting up dependencies ---");
        console.log("Setting futures contract in escrow...");
        escrow.setFuturesContract(address(futuresContract));
        
        console.log("Setting trading contract in escrow...");
        escrow.setTradingContract(address(trading));
        
        console.log("Setting MEV contract in futures...");
        futuresContract.setMEVContract(address(mev));

        vm.stopBroadcast();

        console.log("\n--- DEPLOYMENT COMPLETE ---");
        console.log(
            "IMPORTANT: The real contract addresses will be in the broadcast JSON file:"
        );
        console.log(
            "Path:",
            string.concat(
                "broadcast/Deploy.s.sol/",
                vm.toString(block.chainid),
                "/run-latest.json"
            )
        );
        console.log("Look for 'contractAddress' fields in the receipts array");
        console.log("Order: AccessControl (receipts[0]), Escrow (receipts[1]), FuturesContract (receipts[2]), Trading (receipts[3]), MEV (receipts[4])");
        console.log("=== FGO Futures Deployment Complete ===");
    }
}