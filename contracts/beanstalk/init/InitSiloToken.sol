/*
 SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.20;

interface IBeanstalk {
    function whitelistToken(address token, bytes4 selector, uint32 stalk, uint32 seeds) external;
}

contract InitSiloToken {
    function init(address token, bytes4 selector, uint32 stalk, uint32 seeds) external {
        IBeanstalk(address(this)).whitelistToken(token, selector, stalk, seeds);
    }
}
