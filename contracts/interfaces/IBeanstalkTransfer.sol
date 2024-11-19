// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum From {
    EXTERNAL,
    INTERNAL,
    EXTERNAL_INTERNAL,
    INTERNAL_TOLERANT
}
enum To {
    EXTERNAL,
    INTERNAL
}

interface IBeanstalkTransfer {
    function transferInternalTokenFrom(
        IERC20 token,
        address sender,
        address recipient,
        uint256 amount,
        To toMode
    ) external payable;

    function transferDeposit(
        address sender,
        address recipient,
        address token,
        int96 stem,
        uint256 amount
    ) external payable returns (uint256 bdv);

    function transferDeposits(
        address sender,
        address recipient,
        address token,
        int96[] calldata stems,
        uint256[] calldata amounts
    ) external payable returns (uint256[] memory bdvs);
}
