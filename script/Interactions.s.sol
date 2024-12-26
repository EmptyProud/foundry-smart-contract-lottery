// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, CodeConstant} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    // 1. Default
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        // We need to get the vrf mock coordinator address from the HelperConfig
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator; // It will just return the vrfCoordinator address
        address account = helperConfig.getConfig().account;

        // Create Subscription......
        (uint256 subId,) = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    // 2. Passing our own vrfCoordinator address
    // We put the create subscription with its own function, so it's a little bit easier n more modular
    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
        // Do some console logging to tell what's going on
        console2.log("Creating subscription on Chain Id: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        // It's a Solidity mechanism to interact with a contract at a known address without creating a new instant in memory or
        // providing its constructor parameters
        // The constructor parameters are not needed because we are not creating a new instance of the contract, we are just interacting with it
        // We r telling the compiler that the address vrfCoordinator should be treated an instance of the VRFCoordinatorV2_5Mock contract
        // This chunk of code would be equivalent to going to the chainlink vrf subscription manager and creating a new subscription
        vm.stopBroadcast();
        console2.log("Your subscription Id is: ", subId);
        console2.log("Please update the subscription Id in your HelperConfig.s.sol"); // Bcs we r using subId in our test
        return (subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstant {
    uint256 public constant FUND_AMOUNT = 300 ether; // 3 LINK, bcs LINK kind of runs with this 18 decimal places thing

    function fundSubscriptionUsingConfig() public {
        // We need vrfCoordinatorV2, our subscriptionId, LINK token
        // We need LINK token as LINK token is the token that we r actually making the transaction call to
        // So we need to add a LNK token in our HelperConfig contract
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account)
        public
    {
        console2.log("Funding subscription: ", subscriptionId);
        console2.log("Using vrfCoordinator: ", vrfCoordinator);
        console2.log("On chainId: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId, account);
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) public {
        console2.log("Adding consumer contract: ", contractToAddToVrf);
        console2.log("To VRF Coordinator: ", vrfCoordinator);
        console2.log("On chainId: ", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        // addConsumer() is a function that can used by VRFCoordinatorV2_5Mock contract
        // as it inherited a contract called, SubscriptionAPI which has this function
        vm.stopBroadcast();
    }

    function run() external {
        // We can get our most recent deployment by using our run() function here
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
