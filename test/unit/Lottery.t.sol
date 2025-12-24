// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

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

    function testDontAllowPlayersToEnterLotteryWhileCalculating() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entryFees}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

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

    function testCheckUpKeepReturnsFalseIfLotteryIsntOpen() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entryFees}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        lottery.performUpkeep("");

        (bool upKeepNeeded,) = lottery.checkUpkeep("");
        assert(!upKeepNeeded);
    }

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entryFees}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

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
}
