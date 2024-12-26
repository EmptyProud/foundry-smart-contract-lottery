// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script, HelperConfig {
    function deployContract() public returns (Raffle, HelperConfig) {
        // HelperConfig, so that we can use it directly in our test
        HelperConfig helperConfig = new HelperConfig();
        // local -> deploy mocks, get local config
        // sepolia -> get sepolia config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            // Create a subscription
            CreateSubscription createSubscription = new CreateSubscription();
            // To be extra explicit that using the exact same address that's going to be used in this test
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscription.createSubscription(config.vrfCoordinator, config.account); // we update our subscriptionId

            // Fund Subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.link,
                config.account
            );
        }

        vm.startBroadcast(config.account);
        Raffle deployRaffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        // Add Consumer
        // We need to deploy our raffle contract then only add it as a consumer to the subscription
        // We don't need to broadcast at here as we already have it in our addConsume() function
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(deployRaffle), config.vrfCoordinator, config.subscriptionId, config.account);

        return (deployRaffle, helperConfig);
    }

    function run() external returns (Raffle, HelperConfig) {
        return deployContract();
    }
}
