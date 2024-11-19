/*
 * SPDX-License-Identifier: MIT
 */

pragma solidity ^0.8.20;

import {GaugeDefault} from "./abstract/GaugeDefault.sol";

/**
 * @title GaugeFacet
 * @notice Calculates the gaugePoints for whitelisted Silo LP tokens.
 */
interface IGaugeFacet {
    function defaultGaugePoints(
        uint256 currentGaugePoints,
        uint256 optimalPercentDepositedBdv,
        uint256 percentOfDepositedBdv,
        bytes memory
    ) external pure returns (uint256 newGaugePoints);
}

/**
 * @notice Calculates the gaugePoints for whitelisted Silo LP tokens. Only uses the
 *  default gauge point calculation.
 * @dev The GaugePoint calculation implementation does not use Beanstalk state and does
 * not need to be implemented as a Facet. However, it is implemented as a Facet here for
 * convenience, since the majority of tokens are expected to use the default gauge point
 * calculation and the calculation is not require any token-specific state.
 */
contract GaugeFacet is GaugeDefault {}
