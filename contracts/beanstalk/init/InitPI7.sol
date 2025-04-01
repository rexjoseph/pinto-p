/*
 SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.20;
import "../../libraries/LibAppStorage.sol";
import {Gauge, GaugeId} from "contracts/beanstalk/storage/System.sol";
import {LibGaugeHelpers} from "../../libraries/LibGaugeHelpers.sol";
import {IGaugeFacet} from "contracts/beanstalk/facets/sun/GaugeFacet.sol";

/**
 * @title InitPI7
 * @dev Initializes parameters for pinto improvement 7.
 **/
contract InitPI7 {
    // Convert Up Bonus Gauge
    // Value
    uint256 internal constant INIT_SEASONS_BELOW_PEG = 0;
    uint256 internal constant INIT_CONVERT_UP_BONUS_RATIO = 0;
    uint256 internal constant INIT_BONUS_STALK_PER_BDV = 0;
    // Gauge Data
    uint256 internal constant INIT_DELTA_C = 2e18;
    uint256 internal constant INIT_MIN_DELTA_C = 1e18;
    uint256 internal constant INIT_MAX_DELTA_C = 0;
    uint256 internal constant INIT_PREVIOUS_SEASON_BVD_CONVERTED = 0;
    uint256 internal constant INIT_PREVIOUS_SEASON_BVD_CAPACITY = 0;

    // Excessive price threshold constant
    uint256 internal constant EXCESSIVE_PRICE_THRESHOLD = 1.025e6;

    function init() external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Update Q.
        s.sys.evaluationParameters.excessivePriceThreshold = EXCESSIVE_PRICE_THRESHOLD;

        // Initialize and add convertUpBonusGauge.
        Gauge memory convertUpBonusGauge = Gauge(
            abi.encode(INIT_SEASONS_BELOW_PEG, INIT_CONVERT_UP_BONUS_RATIO, INIT_BONUS_STALK_PER_BDV),
            address(this),
            IGaugeFacet.convertUpBonusGauge.selector,
            abi.encode(
                INIT_DELTA_C,
                INIT_MIN_DELTA_C,
                INIT_MAX_DELTA_C,
                INIT_PREVIOUS_SEASON_BVD_CONVERTED,
                INIT_PREVIOUS_SEASON_BVD_CAPACITY
            )
        );
        LibGaugeHelpers.addGauge(GaugeId.CONVERT_UP_BONUS, convertUpBonusGauge);
    }
}
