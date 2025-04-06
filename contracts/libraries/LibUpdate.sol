/*
 SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.20;
import "../../libraries/LibAppStorage.sol";

/**
 * @title LibUpdate
 * @dev Library for updating parameters.
 */
library LibUpdate {
    event UpdatedExtEvaluationParameters(
        uint256 indexed season,
        ExtEvaluationParameters newExtEvaluationParameters
    );

    event UpdatedEvaluationParameters(
        uint256 indexed season,
        EvaluationParameters newEvaluationParameters
    );
}
