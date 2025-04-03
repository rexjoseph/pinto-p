// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBeanstalk} from "contracts/interfaces/IBeanstalk.sol";
import {console} from "forge-std/console.sol";

/**
 * @title LibSiloHelpers
 * @author FordPinto
 * @notice Library with helper functions for Silo operations
 */
library LibSiloHelpers {
    struct WithdrawalPlan {
        address[] sourceTokens;
        int96[][] stems;
        uint256[][] amounts;
        uint256[] availableBeans;
        uint256 totalAvailableBeans;
    }

    // Struct to hold variables for the combineWithdrawalPlans function
    struct CombineWithdrawalPlansStruct {
        address[] tempSourceTokens;
        int96[][] tempStems;
        uint256[][] tempAmounts;
        uint256[] tempAvailableBeans;
        uint256 totalSourceTokens;
        uint256 whitelistLength;
        address token;
        uint256 maxPossibleStems;
        int96[] stems;
        uint256[] amounts;
        uint256 seenStemsCount;
        uint256 i;
        uint256 j;
        uint256 k;
        uint256 l;
        uint256 m;
        bool found;
    }

    /**
     * @notice Combines multiple withdrawal plans into a single plan
     * @dev This function aggregates the amounts used from each deposit across all plans
     * @param plans Array of withdrawal plans to combine
     * @return combinedPlan A single withdrawal plan that represents the total usage across all input plans
     */
    function combineWithdrawalPlans(
        WithdrawalPlan[] memory plans,
        IBeanstalk beanstalk
    ) external view returns (WithdrawalPlan memory combinedPlan) {
        if (plans.length == 0) {
            return combinedPlan;
        }

        IBeanstalk.WhitelistStatus[] memory whitelistStatuses = beanstalk.getWhitelistStatuses();

        // Initialize the struct with shared variables
        CombineWithdrawalPlansStruct memory vars;
        vars.whitelistLength = whitelistStatuses.length;

        // Initialize arrays for the combined plan with maximum possible size
        vars.tempSourceTokens = new address[](vars.whitelistLength);
        vars.tempStems = new int96[][](vars.whitelistLength);
        vars.tempAmounts = new uint256[][](vars.whitelistLength);
        vars.tempAvailableBeans = new uint256[](vars.whitelistLength);
        vars.totalSourceTokens = 0;

        // Initialize total available beans
        combinedPlan.totalAvailableBeans = 0;

        // Process each whitelisted token
        for (vars.i = 0; vars.i < vars.whitelistLength; vars.i++) {
            vars.token = whitelistStatuses[vars.i].token;

            // Calculate maximum possible stems for this token
            vars.maxPossibleStems = 0;
            for (vars.j = 0; vars.j < plans.length; vars.j++) {
                for (vars.k = 0; vars.k < plans[vars.j].sourceTokens.length; vars.k++) {
                    if (plans[vars.j].sourceTokens[vars.k] == vars.token) {
                        vars.maxPossibleStems += plans[vars.j].stems[vars.k].length;
                    }
                }
            }

            // Skip tokens with no stems
            if (vars.maxPossibleStems == 0) {
                continue;
            }

            // Create arrays with maximum possible size
            vars.stems = new int96[](vars.maxPossibleStems);
            vars.amounts = new uint256[](vars.maxPossibleStems);
            vars.seenStemsCount = 0;

            // Initialize availableBeans for this token
            vars.tempAvailableBeans[vars.totalSourceTokens] = 0;

            // Sum up amounts for each stem across all plans and calculate availableBeans
            for (vars.j = 0; vars.j < plans.length; vars.j++) {
                for (vars.k = 0; vars.k < plans[vars.j].sourceTokens.length; vars.k++) {
                    if (plans[vars.j].sourceTokens[vars.k] == vars.token) {
                        // Add to availableBeans for this token
                        vars.tempAvailableBeans[vars.totalSourceTokens] += plans[vars.j]
                            .availableBeans[vars.k];

                        // Process stems
                        for (vars.l = 0; vars.l < plans[vars.j].stems[vars.k].length; vars.l++) {
                            int96 stem = plans[vars.j].stems[vars.k][vars.l];
                            uint256 amount = plans[vars.j].amounts[vars.k][vars.l];

                            // Find if we've seen this stem before
                            vars.found = false;
                            for (vars.m = 0; vars.m < vars.seenStemsCount; vars.m++) {
                                if (vars.stems[vars.m] == stem) {
                                    vars.amounts[vars.m] += amount;
                                    vars.found = true;
                                    break;
                                }
                            }

                            if (!vars.found) {
                                vars.stems[vars.seenStemsCount] = stem;
                                vars.amounts[vars.seenStemsCount] = amount;
                                vars.seenStemsCount++;
                            }
                        }
                    }
                }
            }

            // Skip tokens with no stems after processing
            if (vars.seenStemsCount == 0) {
                continue;
            }

            // Sort stems in descending order
            for (vars.j = 0; vars.j < vars.seenStemsCount - 1; vars.j++) {
                for (vars.k = 0; vars.k < vars.seenStemsCount - vars.j - 1; vars.k++) {
                    if (vars.stems[vars.k] < vars.stems[vars.k + 1]) {
                        (vars.stems[vars.k], vars.stems[vars.k + 1]) = (
                            vars.stems[vars.k + 1],
                            vars.stems[vars.k]
                        );
                        (vars.amounts[vars.k], vars.amounts[vars.k + 1]) = (
                            vars.amounts[vars.k + 1],
                            vars.amounts[vars.k]
                        );
                    }
                }
            }

            // Update array lengths
            // Create local variables for assembly block
            int96[] memory stemsArray = vars.stems;
            uint256[] memory amountsArray = vars.amounts;
            uint256 count = vars.seenStemsCount;

            assembly {
                mstore(stemsArray, count)
                mstore(amountsArray, count)
            }

            // Update the struct with the modified arrays
            vars.stems = stemsArray;
            vars.amounts = amountsArray;

            // Store token and its data
            vars.tempSourceTokens[vars.totalSourceTokens] = vars.token;
            vars.tempStems[vars.totalSourceTokens] = vars.stems;
            vars.tempAmounts[vars.totalSourceTokens] = vars.amounts;

            // Add to total available beans
            combinedPlan.totalAvailableBeans += vars.tempAvailableBeans[vars.totalSourceTokens];

            vars.totalSourceTokens++;
        }

        // Create the final arrays with the exact size needed
        combinedPlan.sourceTokens = new address[](vars.totalSourceTokens);
        combinedPlan.stems = new int96[][](vars.totalSourceTokens);
        combinedPlan.amounts = new uint256[][](vars.totalSourceTokens);
        combinedPlan.availableBeans = new uint256[](vars.totalSourceTokens);

        // Copy data to the final arrays
        for (vars.i = 0; vars.i < vars.totalSourceTokens; vars.i++) {
            combinedPlan.sourceTokens[vars.i] = vars.tempSourceTokens[vars.i];
            combinedPlan.stems[vars.i] = vars.tempStems[vars.i];
            combinedPlan.amounts[vars.i] = vars.tempAmounts[vars.i];
            combinedPlan.availableBeans[vars.i] = vars.tempAvailableBeans[vars.i];
        }

        return combinedPlan;
    }
}
