// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19; // we're going to work with a very specific set of contracts that work best with 0.8.19

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
// since it is from the chainlink smart contracts, as u know u need to install this with foundry using chainlink brownie contracts
// forge install smartcontractkit/chainlink-brownie-contracts --no-commit
// If u want specific release version, u can do this: forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit
// N remember to add the remappings for it
/**
 * remappings = [
 * '@chainlink/contracts/=lib/chainlink-brownie-contracts/contracts/src/',
 * ]
 */

// To know the VRFV2PlusClient library, we need to import this
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

// U can add error outside of ur contract
// error NotEnoughEthToEnterRaffle();
// But most of the most we put it inside of our contract

// Having natspec is a great way to annotate ur smart contract especially right at the top of ur smart contract to tell a little bit about ur code base
/**
 * @title A sample Raffle contract
 * @author Lim Shi Han
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */
// @dev is notes for develoers
// @notice is notes for everybody

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    // In this way, users who r reading n get this error will know that where the revert came from
    error Raffle__NotEnoughEthToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /* Type Declarations */
    enum RaffleState {
        // In solidity, each on of these states in our new type will actually be converted to integer
        OPEN, // 0
        CALCULATING // 1

    }

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dex the duration of the lottery in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callBackGasLimit;
    address payable[] private s_players;
    // we put this as storage variable bcs it will be keep changing, right more people r going to constantly enter
    // It need be a payable address as the winner of the lottery is going to need to be paid the money
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // We use enum instead of boolean for each state
    // bool private s_calculatingWinner = false;

    /* Events */
    event RaffleEntered(address indexed player); // a new address, a new player has entered the raffle
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    // To get the address of vrfCoordinator contract, it's similiar like how we get the price feed address
    // constructor(uint256 entranceFee, uint256 interval) VRFConsumerBaseV2Plus (hardCoded_vrfCoordinator)
    // But we want to do it modular instead of hardcoding the address
    // So we put it in our constructor n pass it from our constructor to the vrfConsumerBaseV2Plus constructor
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN; // or RaffleState(0)
    }

    // The enterRaffle() and pickWinner() function is all of what our contract needs to be able to do
    function enterRaffle() external payable {
        // external can be more gas efficient than public
        // Legacy version
        // We want people to pay little eth to enter raffle so that we can have a pool of money for winner
        // require(msg.value >= i_entranceFee, "Not enough ETH to enter raffle");
        // We dont want to use require statement bcs it is more expensive than custom error as it is storing a string

        // Newer version
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthToEnterRaffle();
        }

        // Make sure the raffle is not calculating the winner
        if (s_raffleState != RaffleState(0)) {
            revert Raffle__RaffleNotOpen();
        }

        // Latest version with Solidity 0.8.26
        // This version comes out bcs the whole part of if statement is much harder to read than the require statement
        // It allows us to add custom error inside of our require statement
        // But technically, this feature is only available if u compile ur solidity with "vir" which takes a lot of time to compile
        // AND this is still less gas efficient than the if statement
        // So we will just be using the if statement
        // require(msg.value >= i_entranceFee, NotEnoughEthToEnterRaffle());

        s_players.push(payable(msg.sender)); // remember we need the payable keyword in order to have an address receive ETH

        emit RaffleEntered(msg.sender); // When somebody calls this function, we will emit an event
        // If u dont understand why we need this event, just know as rule of thumb, anytime u update storage, u should emit an event
    }

    // Split the pickWinner() function into checkUpkeep() and performUpkeep()
    // When should the winner be picked?
    /**
     * @dev This is the function that the Chainlink nodes will call to see
     * if the lottery is ready to have a winner picked
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH (has players)
     * 4. Implicitly, your subscription has enough LINK
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return - ignored
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        // performData can be some type of return info about what to do with this upkeep
        // public as we r using it somewhere else
        // checkData is a way to further customize ur chainlink automation if u want the chainlink node to pass some specific information
        // in order to check if it's time to do update
        // We commented the actual variable, /* checkData */, means that it's not being used anywhere in the function
        // Uncommmented it if we want to use it in funciton
        // For now, we r not using it.
        // If we just return bool in our return statement,
        // we need to initialize the upkeepNeeded variable in our function
        // bool upkeepNeeded = false;
        // Then we need like doing: return upkeepNeeded

        // If we put bool upkeepNeeded in our return statement, we dont need to initialize it in our function
        // it is initialize as false when we do upkeepNeeded in the return statement
        // We can also do this: upkeepNeeded = true, then it will then return true, we dont need like doing: return upkeepNeeded;

        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers; // u can just leave it like this
        // But if u want to be more explicit, u can do this:
        return (upkeepNeeded, hex""); // or (upkeepNeeded, "") or (upkeepNeeded, "0x0")
    }

    // Refactor
    function performUpkeep(bytes calldata /* performData */ ) external {
        // Since it is a external function, which means anybody can call this function
        // We need to have some validation to make sure that only the chainlink node can call this function when it's time to call this
        (bool upkeepNeeded,) = checkUpkeep("");
        // ur("") will get error:
        // Invalid type for argument in function call. Invalid implicit conversion from literal_string "" to bytes calldata requested
        // So we need to swap it to memory keyword in the checkUpkeep function
        // Reason:
        // In our checkUpkeep() function, we specified the input parameter as bytes calldata
        // Whenever u use some type of variable inside of a function, it can never be calldata
        // Bcs technically, calldata is a read-only memory space, anything generated from a smart contract is never calldata
        // calldata could only be generated from a user's transaction input
        // The example make it as calldata for more gas efficiency as memory is a bit less gas efficient
        // However, it's more permissive
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callBackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        // This is the actual call to the chainlink coordinator to the chainlink node
        /*uint256 requestId = */
        // s_vrfCoordinator.requestRandomWords(request);

        // Refactor
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId); // But it is redundant as we r emitting n the chainlink vrf coordinator is also emitting it
        // But just for making some of our tests a little bit easier, n also make learning easier, we r adding this emit event
    }

    // We need something to pick the winner
    // 1. Get a random number
    // 2. Use random number to pick a winner
    // 3. Be automatically called

    // // 1. Get a random number
    // function pickWinner() external {
    //     // external can be more gas efficient than public
    //     // In order for us to get the random number, we're going to check that enough time has passed
    //     // We need to pick the time interval for our lottery to last
    //     // Check to see if enough time has passed
    //     // We can do that by getting the current time

    //     // We need to take snapshot of time to keep track of the every time we picked a winner
    //     if ((block.timestamp - s_lastTimeStamp) < i_interval) {
    //         revert();
    //     }
    //     // block.timestamp is a globally available unit similiar like msg.sender, it's the current aproximate time of the blockchain

    //     s_raffleState = RaffleState.CALCULATING; // or RaffleState(1)

    //     // If enough time has indeed passed, we can go ahead n get our random number

    //     // Get our random number 2.5
    //     // 1. Request RNG
    //     // 2. Get RNG

    //     // Out contract dk what is the VRFV2PlusClient, so we need to import it
    //     VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
    //         .RandomWordsRequest({
    //             keyHash: i_keyHash,
    //             subId: i_subscriptionId,
    //             requestConfirmations: REQUEST_CONFIRMATIONS,
    //             callbackGasLimit: i_callBackGasLimit,
    //             numWords: NUM_WORDS,
    //             extraArgs: VRFV2PlusClient._argsToBytes(
    //                 // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
    //                 VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
    //             )
    //         });

    //     // This is the actual call to the chainlink coordinator to the chainlink node
    //     uint256 requestId = s_vrfCoordinator.requestRandomWords(
    //         // we can see that the s_vrfCoordinator is some type of coordinator smart contract n it has a function called requestRandomWords
    //         // The first thing we need to do is get this coordinator address
    //         // So We need to import VRFConsumerBaseV2Plus and let our contract inherit it
    //         // since it is from the chainlink smart contracts, as u know u need to install this with foundry using chainlink brownie contracts
    //         // VRFV2PlusClient.RandomWordsRequest({
    //         //     keyHash: s_keyHash,
    //         //     subId: s_subscriptionId,
    //         //     requestConfirmations: requestConfirmations,
    //         //     callbackGasLimit: callbackGasLimit,
    //         //     numWords: numWords,
    //         //     extraArgs: VRFV2PlusClient._argsToBytes(
    //         //         // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
    //         //         VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
    //         //     )
    //         // })
    //         // For more easy to understand, we comment the whole bunch of stuff and put it outside
    //         // And pass the request object back to here
    //         request
    //     );
    // }

    // 2. Use random number to pick a winner
    function fulfillRandomWords(uint256/*requestId*/, uint256[] calldata randomWords) internal override {
        /* Checks */
        // Conditionals if have

        /* Effect (internal contract state changes) */
        // s_player = 10;
        // rng = 12;
        // 12 % 10 = 2 -> so the index 2 of the array is the winner
        // 234539574723940723847924782379 % 10 = 9 -> so the index 9 of the array is the winner
        // U will also get a number between 0 to 9, which exactly fits out array index size
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        // randomWords[0], it is zero bcs randomWords is going to be an array of size one as that's the random number that we requested
        // We only request one random number
        address payable recentWinner = s_players[indexOfWinner];
        // Patrick like to keep track of the most recent winner, so we can have a very easy readable who's recent winner
        // Declare a storage variable to keep track of the most recent winner
        s_recentWinner = recentWinner;
        // Flip the state back to OPEN
        s_raffleState = RaffleState.OPEN;
        // Reset the s_players array
        s_players = new address payable[](0);
        // Reset time so that our raffle can start again
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner); // Bump event in the Effects section as it doesnt interact with external contracts

        /* Interactions (External contract interaction) */
        // and then we r going to pay the winner\
        (bool success,) = recentWinner.call{value: address(this).balance}("");

        // Make sure this transfer went through successfully
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
