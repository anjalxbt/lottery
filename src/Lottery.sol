// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Lottery {
    error Lottery_EntryFeesNotEnough();

    uint256 private immutable i_entryFees;

    constructor(uint256 entryFees) {
        i_entryFees = entryFees;
    }

    function enterLottery() public payable {
        if (msg.value < i_entryFees) {
            revert Lottery_EntryFeesNotEnough();
        }
    }

    function pickWinner() public {}
}
