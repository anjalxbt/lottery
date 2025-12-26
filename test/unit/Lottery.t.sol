// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    HelperConfig public helperConfig;

    event PlayerEnteredLottery(address indexed player);

    uint256 entryFees;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    LinkToken linkToken;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        DeployLottery deployer = new DeployLottery();
        (lottery, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entryFees = config.entryFees;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        linkToken = LinkToken(config.linkToken);

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testLotteryIntializesInOpenState() public view {
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }

    function testLotteryRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Lottery.Lottery_EntryFeesNotEnough.selector);
        lottery.enterLottery();
    }

    function testLotteryRecordsPlayerWhenEntered() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entryFees}();
        address playerRecorded = lottery.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitEventOnEntry() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(lottery));
        emit PlayerEnteredLottery(PLAYER);
        lottery.enterLottery{value: entryFees}();
    }

    modifier lotteryEnteredAndTimePassed() {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entryFees}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testDontAllowPlayersToEnterLotteryWhileCalculating() public lotteryEnteredAndTimePassed {
        lottery.performUpkeep("");

        vm.expectRevert(Lottery.Lottery_LottryNotOpen.selector);
        vm.prank(PLAYER);
        lottery.enterLottery{value: entryFees}();
    }

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upKeepNeeded,) = lottery.checkUpkeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfLotteryIsntOpen() public lotteryEnteredAndTimePassed {
        lottery.performUpkeep("");

        (bool upKeepNeeded,) = lottery.checkUpkeep("");
        assert(!upKeepNeeded);
    }

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public lotteryEnteredAndTimePassed {
        lottery.performUpkeep("");
    }

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Lottery.LotteryState lState = lottery.getLotteryState();

        vm.expectRevert(
            abi.encodeWithSelector(Lottery.Lottery_UpKeepNotNeeded.selector, currentBalance, numPlayers, lState)
        );
        lottery.performUpkeep("");
    }

    function testPerformUpkeepUpdatesLotteryStateAndEmitsRequestId() public lotteryEnteredAndTimePassed {
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Lottery.LotteryState lotteryState = lottery.getLotteryState();

        assert(uint256(requestId) > 0);
        assert(uint256(lotteryState) == 1);
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        lotteryEnteredAndTimePassed
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(lottery));
    }

    function testFulfillRandomWorkdPicksAWinnerResetsAndSendMoney() public lotteryEnteredAndTimePassed {
        uint256 addonEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + addonEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            lottery.enterLottery{value: entryFees}();
        }

        uint256 startingTimestamp = lottery.getLastTimeStamp();
        uint256 expectedWinnerBalance = expectedWinner.balance;

        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(lottery));

        address recenetWinner = lottery.getRecentWinner();
        Lottery.LotteryState lotteryState = lottery.getLotteryState();
        uint256 winnerBalance = recenetWinner.balance;
        uint256 endingTimeStamp = lottery.getLastTimeStamp();
        uint256 prize = entryFees * (addonEntrants + 1);

        assert(recenetWinner == expectedWinner);
        assert(uint256(lotteryState) == 0);
        assert(winnerBalance == expectedWinnerBalance + prize);
        assert(endingTimeStamp > startingTimestamp);
    }
}
