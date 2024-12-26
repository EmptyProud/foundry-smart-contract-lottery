// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstant} from "script/HelperConfig.s.sol";
import {console2} from "forge-std/console2.sol";

contract RaffleTest is Test, CodeConstant {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    // Make some user to interact with our raffle
    address public USER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        // Make sure the user has enough balance to enter the raffle
        vm.deal(USER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitialinezInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        // OR assert(raffle.getRaffleState() == Raffle.RaffleState(0));
        // OR assert(uint256(raffle.getRaffleState()) == 0);
    }

    function testRaffleEntranceFee() public view {
        assert(raffle.getEntranceFee() == entranceFee);
    }

    // # ------------------------------------------------------------------
    // #                           ENTER RAFFLE
    // # ------------------------------------------------------------------®
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(USER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthToEnterRaffle.selector);
        // By adding parameters, we can even be more precise showing that we r expect to revert with a very specific code
        // Instead of just telling that we gonna revert only to avoid reverting with something which is not related to what we want
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(USER);
        // Act
        raffle.enterRaffle{value: entranceFee}(); // send with entrance fee
        // Assert
        address playerAddress = raffle.getPlayer(0);
        assert(playerAddress == address(USER));
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(USER);
        // Act
        // Telling foundry that we r expecting to emit an event
        vm.expectEmit(true, false, false, false, address(raffle)); // address of raffle as it's going to emitting it
        // The exact event to emit
        emit RaffleEntered(USER);
        // Asset
        raffle.enterRaffle{value: entranceFee}(); // The event will be emitted after this call, and compare with the expected event
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(USER);
        // We will call performUpkeep to change the state of the raffle to CALCULATING
        // So we will have to update the time, as performUpkeep will call checkUpkeep, if we didnt update the time, it will revert
        raffle.enterRaffle{value: entranceFee}(); // We can have balance n player in the raffle, the raffle is also OPEN
        // So lastly we just need to update the time (make sure some time has passed)
        // Wait????? (No, we can use foundry cheatcode, vm.warp and vm.roll)
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); // Do this as kinda best practices, always roll it by the current block.number + 1
        // As this will simulate that the time has changed n also there's one new block has been added
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
    }

    // # ------------------------------------------------------------------
    // #                           CHECKUPKEEP
    // # ------------------------------------------------------------------
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        // We r not calling the enterRaffle here
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep(""); // It should return false as we have no balance

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // This should change the state of the raffle to CALCULATING

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    // Challenge
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    // # ------------------------------------------------------------------
    // #                          PERFORM UPKEEP
    // # ------------------------------------------------------------------
    function testPerformUpkeepCanRunOnlyIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        // Technically there's a slightly better way:
        // bool success = raffle.call(abi.encode.....) // We call the performUpkeep() function
        // assert(success);
        // But as for now, some stuff we havent learned yet, so we r not using it

        // As we havent learned how to use the above method, we can use this method instead
        raffle.performUpkeep(""); // This test will fail if this function fail

        // This is not working, we r expect a custom error that have parameters, n patrick didnt say how
        // If ur custom error dont have parameters, u will find it work, n the test passed
        // (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // console2.log("upkeepNeeded: ", upkeepNeeded);
        // vm.expectRevert(Raffle.Raffle__UpkeepNotNeeded.selector);
        // raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // The way we test this is going to be new
        // As this is the first time that we r testing reverting a custom error with parameters

        // Arrange
        // We r setting these as it will be the parameters that we need to pass to our expected error
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        // U need to update it, as after enter the raffle, ur balance n number of players is no any more 0
        currentBalance = currentBalance + entranceFee;
        numPlayers = numPlayers + 1;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        vm.prank(USER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // what if we need to get data from emitted events in our tests?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        // Arrange
        // vm.prank(USER);
        // raffle.enterRaffle{value: entranceFee}();
        // vm.warp(block.timestamp + interval + 1);
        // vm.roll(block.number + 1);
        // We replace it by using the modifier

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Calling these recordLogs n performUpkeep
        // Whatever events or logs r emitted by this performUpkeep() function,
        // recordLogs will keep track of those n stick them into an array
        // We can walk through this array n grab the different value in it
        bytes32 requestId = entries[1].topics[1]; // requestId is bytes32 bcs verything in these logs is going to be stored as a bytes32
        // The first log that get emitted actually is going to be the vrf itself, n that would be entries[0]
        // We r using topics[1] instead of topics[0] as topics[0] is essentially always reserved for something else (we will learn later)

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0); // We typecast bytes32 to uint256 for requestId
        // We just asserting to just make sure there was a requestId that was not blank
        assert(uint256(raffleState) == 1);
        // We make sure we have a requestId n make sure we get this requestId when the raffle state is actually converted
    }

    // # ------------------------------------------------------------------
    // #                        FULFILLRANDOMWORDS
    // # ------------------------------------------------------------------
    modifier skipFork() {
        if (block.chainid != CodeConstant.LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        // How can we test fulfillRandomWords() can only be called after performUpkeep()?
        // We can rely on our vrf coordinator mock or just our vrfCoordinator
        // In the contract of the vrfCoordinator, the fulfillRandomWords() function has a if statement that checks if the requestId is 0
        // or it will return an invalidRequest error

        // Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
        // When we running this test here, we r pretending to be the vrf coordinator
        // We r using the vrf coordinator mock which allows anybody to call fulfillRandomWords() as it's a mock
        // In the actual vrf coordinator, not everybody can call this fulfillRandomWords(), only the chainlink nodes themselves can call
    }

    function testFulfillRandomWordsPickWinnerResetsAndSendsMoney() public raffleEntered skipFork {
        // As an end to end test
        // Once the chainlink vrf calls fulfillRandomWords(), it's gonna pick a winner, reset the whole array of players, sends winner the money

        // Arrange
        uint256 additionalEntrants = 3; // 4 players in total entering the raffle
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i)); // This is kind of cheaty way to convert any number into an address
            hoax(newPlayer, 10 ether); // It sets up a prank and gives them some ether
            raffle.enterRaffle{value: entranceFee}();
        }

        // Make sure timestamps are updated
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // Pretend to be the vrf coordinator n call fulfillRandomWords()
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        // Make sure the winner is correct
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }

    function testFulfillRandomWordsRevertsIfTransferFails() public skipFork {
        // Arrange
        // uint256 additionalEntrants = 3; // 4 players in total entering the raffle
        // uint256 startingIndex = 1;
        TestRevertReceiver userThatWillRevertWhenReceiveEther = new TestRevertReceiver();

        // for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
        //     address newPlayer = address(uint160(i));
        //     hoax(newPlayer, 0.01 ether); // We dont give them a starting balance
        //     raffle.enterRaffle{value: entranceFee}();
        // }
        vm.deal(address(userThatWillRevertWhenReceiveEther), 0.01 ether);
        vm.prank(address(userThatWillRevertWhenReceiveEther));
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        // Use -vvvv to check whether it actually reverts this Raffle__TransferFailed() customer error
    }
}

contract TestRevertReceiver is Test {
    receive() external payable {
        revert();
    }
}
