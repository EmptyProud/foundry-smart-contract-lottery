// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {CreateSubscription} from "script/Interactions.s.sol";
import {FundSubscription} from "script/Interactions.s.sol";
import {AddConsumer} from "script/Interactions.s.sol";
import {CodeConstant} from "script/HelperConfig.s.sol";
import {console2} from "forge-std/Script.sol";

contract interactions is Test, CodeConstant {
    Raffle public raffle;
    HelperConfig public helperConfig;
    CreateSubscription createSubscription = new CreateSubscription();
    FundSubscription fundSubscription = new FundSubscription();
    AddConsumer addConsumer = new AddConsumer();

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    address account;

    address public USER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 100000 ether;

    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        link = config.link;
        account = config.account;

        // Make sure the user has enough balance to enter the raffle
        vm.deal(USER, STARTING_PLAYER_BALANCE);
    }

    // # ------------------------------------------------------------------
    // #                       CREATE SUBSCRIPTION
    // # ------------------------------------------------------------------

    function testCreatingSubscriptionUsingConfig() public skipFork{
        // Arrange / Act
        uint256 subIdBefore = helperConfig.getConfig().subscriptionId;
        console2.log("Subscription Id before: ", subIdBefore);

        (uint256 subIdAfter,) = createSubscription.createSubscriptionUsingConfig();
        console2.log("Subscription Id after: ", subIdAfter);

        // Assert
        assert(subIdBefore == 0);
        assert(subIdAfter != 0); 
    }

    function testCreatingSubscriptionUsingRun() public {
        // Arrange / Act / Assert
        (bool success,) = address(createSubscription).call(abi.encodeWithSignature("run()"));
        assert(success);
    }

    // # ------------------------------------------------------------------
    // #                        FUND SUBSCRIPTION
    // # ------------------------------------------------------------------
    modifier skipFork() {
        if (block.chainid != CodeConstant.LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFundingSubscriptionUsingConfig() public skipFork{
        // Arrange / Act
        createSubscription.createSubscription(vrfCoordinator,account);

        // Act / Assert
        vm.expectRevert();
        fundSubscription.fundSubscriptionUsingConfig();

        assert(subscriptionId == 0);
    }

    function testFundSubscriptionUsingRun() public skipFork{
        // Arrange / Act / Assert
        (bool success,) = address(fundSubscription).call(abi.encodeWithSignature("run()"));
        assert(!success);
    }

    // # ------------------------------------------------------------------
    // #                           ADD CONSUMER
    // # ------------------------------------------------------------------
    modifier skipLocal() {
        if (block.chainid == CodeConstant.LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testAddConsumerUsingConfigForFork() public skipLocal{
        // Arrange / Act
        (bool success,) = address(addConsumer).call(abi.encodeWithSignature("addConsumerUsingConfig(address)", address(raffle)));

        // Assert
        assert(success);
    }

    function testAddConsumerUsingConfigForLocal() public {
        // Arrange / Act
        (bool success,) = address(addConsumer).call(abi.encodeWithSignature("addConsumerUsingConfig(address)", address(raffle)));

        // Assert
        assert(!success);
    }

    function testAddConsumerUsingRun() public {
        // Arrange / Act
        (bool success,) = address(addConsumer).call(abi.encodeWithSignature("run()"));

        // Assert
        assert(!success);
    }
}