/*
 SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.20;

import "../../libraries/LibAppStorage.sol";
import {LibWhitelist} from "../../libraries/Silo/LibWhitelist.sol";
import {LibWhitelistedTokens} from "../../libraries/Silo/LibWhitelistedTokens.sol";

/**
 * @title InitWhitelistRebalance
 * @dev Dewhitelists tokens and rebalances optimal percent deposited allocation for remaining tokens.
 **/
contract InitWhitelistRebalance {

    // Currently whitelisted tokens
    address internal constant PINTO_WETH_LP = 0x3e11001CfbB6dE5737327c59E10afAB47B82B5d3;
    address internal constant PINTO_CBETH_LP = 0x3e111115A82dF6190e36ADf0d552880663A4dBF1;
    address internal constant PINTO_CBBTC_LP = 0x3e11226fe3d85142B734ABCe6e58918d5828d1b4;
    address internal constant PINTO_USDC_LP = 0x3e1133aC082716DDC3114bbEFEeD8B1731eA9cb1;
    address internal constant PINTO_WSOL_LP = 0x3e11444c7650234c748D743D8d374fcE2eE5E6C9;

    // New optimal percent deposited BDV allocations for remaining tokens
    uint64 internal constant PINTO_CBETH_LP_OPTIMAL_PERCENT_DEPOSITED_BDV = 33_333333; // 33%
    uint64 internal constant PINTO_CBBTC_LP_OPTIMAL_PERCENT_DEPOSITED_BDV = 33_333333; // 33%
    uint64 internal constant PINTO_USDC_LP_OPTIMAL_PERCENT_DEPOSITED_BDV = 33_333333; // 33%

    // New optimal percent deposited BDV allocations for remaining tokens
    struct TokenAllocation {
        address token;
        uint64 optimalPercentDepositedBdv;
    }

    function init() external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Define the new allocations
        TokenAllocation[] memory newAllocations = new TokenAllocation[](3);

        // Initialize the new allocations array with the new allocations
        newAllocations[0] = TokenAllocation({
            token: PINTO_CBETH_LP,
            optimalPercentDepositedBdv: PINTO_CBETH_LP_OPTIMAL_PERCENT_DEPOSITED_BDV
        });
        newAllocations[1] = TokenAllocation({
            token: PINTO_CBBTC_LP,
            optimalPercentDepositedBdv: PINTO_CBBTC_LP_OPTIMAL_PERCENT_DEPOSITED_BDV
        });
        newAllocations[2] = TokenAllocation({
            token: PINTO_USDC_LP,
            optimalPercentDepositedBdv: PINTO_USDC_LP_OPTIMAL_PERCENT_DEPOSITED_BDV
        });

        // Validate total allocations don't exceed 100%
        _validateTotalAllocations(newAllocations);

        // Dewhitelist token
        _dewhitelistToken(PINTO_WSOL_LP);
        _dewhitelistToken(PINTO_WETH_LP);

        // Rebalance the optimal percent deposited BDV for remaining tokens
        _rebalanceTokenAllocations(newAllocations);
    }

    function _dewhitelistToken(address token) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Verify token is currently whitelisted
        require(
            s.sys.silo.assetSettings[token].milestoneSeason != 0,
            "InitWhitelistRebalance: Token not whitelisted"
        );
        // Dewhitelist the token using LibWhitelist
        LibWhitelist.dewhitelistToken(token);
    }

    function _rebalanceTokenAllocations(TokenAllocation[] memory newAllocations) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Update optimal percent deposited BDV for each token in the rebalancing list
        for (uint256 i = 0; i < newAllocations.length; i++) {
            TokenAllocation memory allocation = newAllocations[i];

            // Verify token is still whitelisted
            require(
                s.sys.silo.assetSettings[allocation.token].milestoneSeason != 0,
                "InitWhitelistRebalance: Token not whitelisted for rebalancing"
            );

            // Update the optimal percent deposited BDV
            LibWhitelist.updateOptimalPercentDepositedBdvForToken(
                allocation.token,
                allocation.optimalPercentDepositedBdv
            );
        }
    }

    // Helper function to validate total allocations don't exceed 100%
    function _validateTotalAllocations(TokenAllocation[] memory newAllocations) internal view {
        uint256 totalPercent = 0;
        for (uint256 i = 0; i < newAllocations.length; i++) {
            totalPercent += newAllocations[i].optimalPercentDepositedBdv;
        }
        require(
            totalPercent <= 100e6, // 100% in basis points
            "InitWhitelistRebalance: Total allocations exceed 100%"
        );
    }
}
