// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Lottery {
    error Lottery_EntryFeesNotEnough();

    uint256 private immutable I_ENTRY_FEES;
    address payable[] s_players;
    uint256 immutable i_interval;
    uint256 private s_lastTimeStamp;

    event PlayerEnteredLottery(address indexed player);

    constructor(uint256 entryFees, uint256 interval) {
        I_ENTRY_FEES = entryFees;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    function enterLottery() public payable {
        if (msg.value < I_ENTRY_FEES) {
            revert Lottery_EntryFeesNotEnough();
        }
        s_players.push(payable(msg.sender));
        emit PlayerEnteredLottery(msg.sender);
    }

    function pickWinner() public {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
    }

    function getEntryFees() external view returns (uint256) {
        return I_ENTRY_FEES;
    }
}
