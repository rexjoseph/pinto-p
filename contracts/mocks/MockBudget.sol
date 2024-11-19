// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IBudget} from "contracts/interfaces/IBudget.sol";

contract MockBudget is IBudget {
    event Distribute();

    constructor() {}

    function distribute() external {
        emit Distribute();
    }
}
