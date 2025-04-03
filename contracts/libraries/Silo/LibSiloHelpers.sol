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
        // First pass: count unique source tokens
        uint256 maxSourceTokens = whitelistStatuses.length;

        // Prefill combinedPlan.sourceTokens with beanstalk.getWhitelistedStatuses()
        combinedPlan.sourceTokens = new address[](maxSourceTokens);
        for (uint256 i = 0; i < maxSourceTokens; i++) {
            combinedPlan.sourceTokens[i] = whitelistStatuses[i].token;
        }

        uint256 totalSourceTokens = 0;

        // Initialize arrays for the combined plan
        combinedPlan.stems = new int96[][](maxSourceTokens);
        combinedPlan.amounts = new uint256[][](maxSourceTokens);
        combinedPlan.availableBeans = new uint256[](maxSourceTokens);

        // Second pass: combine stems, amounts, and availableBeans for each source token
        for (uint256 i = 0; i < maxSourceTokens; i++) {
            console.log("i", i);
            // Calculate absolute maximum possible stems by adding up all stem array lengths
            uint256 maxPossibleStems = 0;

            for (uint256 j = 0; j < plans.length; j++) {
                for (uint256 k = 0; k < plans[j].sourceTokens.length; k++) {
                    if (plans[j].sourceTokens[k] == combinedPlan.sourceTokens[i]) {
                        maxPossibleStems += plans[j].stems[k].length;
                    }
                }
            }

            console.log("maxPossibleStems", maxPossibleStems);

            // Create arrays with maximum possible size
            int96[] memory stems = new int96[](maxPossibleStems);
            uint256[] memory amounts = new uint256[](maxPossibleStems);
            uint256 seenStemsCount = 0;

            // Sum up amounts for each stem across all plans
            for (uint256 j = 0; j < plans.length; j++) {
                for (uint256 k = 0; k < plans[j].sourceTokens.length; k++) {
                    if (plans[j].sourceTokens[k] == combinedPlan.sourceTokens[i]) {
                        for (uint256 l = 0; l < plans[j].stems[k].length; l++) {
                            int96 stem = plans[j].stems[k][l];
                            uint256 amount = plans[j].amounts[k][l];

                            // Find if we've seen this stem before
                            bool found = false;
                            for (uint256 m = 0; m < seenStemsCount; m++) {
                                if (stems[m] == stem) {
                                    amounts[m] += amount;
                                    found = true;
                                    break;
                                }
                            }

                            if (!found) {
                                stems[seenStemsCount] = stem;
                                amounts[seenStemsCount] = amount;
                                seenStemsCount++;
                            }
                        }
                    }
                }
            }

            console.log("seenStemsCount", seenStemsCount);

            if (seenStemsCount == 0) {
                continue;
            }

            totalSourceTokens++;

            console.log("totalSourceTokens", totalSourceTokens);

            // Sort stems in descending order
            for (uint256 j = 0; j < seenStemsCount - 1; j++) {
                for (uint256 k = 0; k < seenStemsCount - j - 1; k++) {
                    if (stems[k] < stems[k + 1]) {
                        (stems[k], stems[k + 1]) = (stems[k + 1], stems[k]);
                        (amounts[k], amounts[k + 1]) = (amounts[k + 1], amounts[k]);
                    }
                }
            }

            // Update array lengths
            assembly {
                mstore(stems, seenStemsCount)
                mstore(amounts, seenStemsCount)
            }

            combinedPlan.stems[i] = stems;
            combinedPlan.amounts[i] = amounts;

            // Sum up availableBeans from all plans for this source token
            combinedPlan.availableBeans[i] = 0;
            for (uint256 j = 0; j < plans.length; j++) {
                for (uint256 k = 0; k < plans[j].sourceTokens.length; k++) {
                    if (plans[j].sourceTokens[k] == combinedPlan.sourceTokens[i]) {
                        combinedPlan.availableBeans[i] += plans[j].availableBeans[k];
                        break; // Break after finding the matching source token in this plan
                    }
                }
            }
        }

        // Calculate total available beans
        combinedPlan.totalAvailableBeans = 0;
        for (uint256 i = 0; i < totalSourceTokens; i++) {
            combinedPlan.totalAvailableBeans += combinedPlan.availableBeans[i];
        }

        return combinedPlan;
    }
}
