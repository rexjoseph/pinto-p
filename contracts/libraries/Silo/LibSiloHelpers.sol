// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
        WithdrawalPlan[] memory plans
    ) external pure returns (WithdrawalPlan memory combinedPlan) {
        if (plans.length == 0) {
            return combinedPlan;
        }

        // First pass: count unique source tokens
        uint256 totalSourceTokens = 0;
        for (uint256 i = 0; i < plans.length; i++) {
            for (uint256 j = 0; j < plans[i].sourceTokens.length; j++) {
                bool found = false;
                for (uint256 k = 0; k < totalSourceTokens; k++) {
                    if (combinedPlan.sourceTokens[k] == plans[i].sourceTokens[j]) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    if (totalSourceTokens >= combinedPlan.sourceTokens.length) {
                        // Resize arrays
                        address[] memory newSourceTokens = new address[](totalSourceTokens + 1);
                        for (uint256 k = 0; k < totalSourceTokens; k++) {
                            newSourceTokens[k] = combinedPlan.sourceTokens[k];
                        }
                        combinedPlan.sourceTokens = newSourceTokens;
                    }
                    combinedPlan.sourceTokens[totalSourceTokens] = plans[i].sourceTokens[j];
                    totalSourceTokens++;
                }
            }
        }

        // Initialize arrays for the combined plan
        combinedPlan.stems = new int96[][](totalSourceTokens);
        combinedPlan.amounts = new uint256[][](totalSourceTokens);
        combinedPlan.availableBeans = new uint256[](totalSourceTokens);

        // Second pass: combine stems, amounts, and availableBeans for each source token
        for (uint256 i = 0; i < totalSourceTokens; i++) {
            // Create arrays for this source token
            int96[] memory stems = new int96[](plans.length * 10); // Reasonable max size
            uint256[] memory amounts = new uint256[](plans.length * 10);
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
