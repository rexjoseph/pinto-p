// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IWell, Call, IERC20} from "contracts/interfaces/basin/IWell.sol";
import {IWellUpgradeable} from "contracts/interfaces/basin/IWellUpgradeable.sol";

/**
 * @title LibWellDeployer
 * @notice LibWellDeployer provides helper functions for deploying Wells with Aquifers.
 */
library LibWellDeployer {
    /**
     * @notice Encode the Well's deployment data.
     * Init data are encoded using the initNoWellToken selector for upgradeable Wells.
     */
    function encodeUpgradeableWellDeploymentData(
        address _aquifer,
        IERC20[] memory _tokens,
        Call memory _wellFunction,
        Call[] memory _pumps
    ) internal pure returns (bytes memory immutableData, bytes memory initData) {
        immutableData = encodeWellImmutableData(_aquifer, _tokens, _wellFunction, _pumps);
        initData = abi.encodeWithSelector(IWellUpgradeable.initNoWellToken.selector);
    }

    /**
     * @notice Encode the Well's deployment data.
     * Init data are encoded using the init selector with a name and symobol
     * for non-upgradeable Wells.
     */
    function encodeWellDeploymentData(
        address _aquifer,
        IERC20[] memory _tokens,
        Call memory _wellFunction,
        Call[] memory _pumps,
        string memory name,
        string memory symbol
    ) internal pure returns (bytes memory immutableData, bytes memory initData) {
        immutableData = encodeWellImmutableData(_aquifer, _tokens, _wellFunction, _pumps);
        initData = abi.encodeWithSignature("init(string,string)", name, symbol);
    }

    function encodeWellImmutableData(
        address _aquifer,
        IERC20[] memory _tokens,
        Call memory _wellFunction,
        Call[] memory _pumps
    ) internal pure returns (bytes memory immutableData) {
        immutableData = abi.encodePacked(
            _aquifer, // aquifer address
            _tokens.length, // number of tokens
            _wellFunction.target, // well function address
            _wellFunction.data.length, // well function data length
            _pumps.length, // number of pumps
            _tokens, // tokens array
            _wellFunction.data // well function data (bytes)
        );
        for (uint256 i; i < _pumps.length; ++i) {
            immutableData = abi.encodePacked(
                immutableData, // previously packed pumps
                _pumps[i].target, // pump address
                _pumps[i].data.length, // pump data length
                _pumps[i].data // pump data (bytes)
            );
        }
    }
}
