/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Invariable} from "contracts/beanstalk/Invariable.sol";
import {ReentrancyGuard} from "contracts/beanstalk/ReentrancyGuard.sol";
import {LibTractor} from "contracts/libraries/LibTractor.sol";

/**
 * @title TokenSupportFacet
 * @notice Transfer ERC-721 and ERC-1155 tokens.
 * @dev To transfer ERC-20 tokens, use {TokenFacet.transferToken}.
 **/

contract TokenSupportFacet is Invariable, ReentrancyGuard {
    /**
     *
     * ERC-721
     *
     **/

    /**
     * @notice Execute an ERC-721 token transfer
     * @dev Wraps {IERC721-safeBatchTransferFrom}.
     **/
    function transferERC721(
        IERC721 token,
        address to,
        uint256 id
    ) external payable fundsSafu noNetFlow noSupplyChange nonReentrant {
        token.safeTransferFrom(LibTractor._user(), to, id);
    }

    /**
     *
     * ERC-1155
     *
     **/

    /**
     * @notice Execute an ERC-1155 token transfer of a single Id.
     * @dev Wraps {IERC1155-safeTransferFrom}.
     **/
    function transferERC1155(
        IERC1155 token,
        address to,
        uint256 id,
        uint256 value
    ) external payable fundsSafu noNetFlow noSupplyChange nonReentrant {
        token.safeTransferFrom(LibTractor._user(), to, id, value, new bytes(0));
    }

    /**
     * @notice Execute an ERC-1155 token transfer of multiple Ids.
     * @dev Wraps {IERC1155-safeBatchTransferFrom}.
     **/
    function batchTransferERC1155(
        IERC1155 token,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values
    ) external payable fundsSafu noNetFlow noSupplyChange nonReentrant {
        token.safeBatchTransferFrom(LibTractor._user(), to, ids, values, new bytes(0));
    }
}
