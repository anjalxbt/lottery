// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Lottery {
    error Lottery_EntryFeesNotEnough();

    uint256 private immutable i_entryFees;
    address payable[] s_players;

    event PlayerEnteredLottery(address indexed player);

    constructor(uint256 entryFees) {
        i_entryFees = entryFees;
    }

    function enterLottery() public payable {
        if (msg.value < i_entryFees) {
            revert Lottery_EntryFeesNotEnough();
        }
        s_players.push(payable(msg.sender));
        emit PlayerEnteredLottery(msg.sender);
    }

    function pickWinner() public {}

    function getEntryFees() external view returns (uint256) {
        return i_entryFees;
    }
}
