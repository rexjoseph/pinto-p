/*
 SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.20;
import {AppStorage, LibAppStorage} from "../../libraries/LibAppStorage.sol";
import {Gauge, GaugeId} from "contracts/beanstalk/storage/System.sol";
import {LibGaugeHelpers} from "../../libraries/LibGaugeHelpers.sol";
import {IGaugeFacet} from "contracts/beanstalk/facets/sun/GaugeFacet.sol";

/**
 * @title InitPI11
 * @dev Initializes parameters for pinto improvement 11.
 * Updates the convert down penalty gauge to include new fields.
 **/
contract InitPI11 {
    uint256 internal constant INIT_CONVERT_DOWN_PENALTY_RATIO = 0;
    uint256 internal constant INIT_ROLLING_SEASONS_ABOVE_PEG = 0;
    uint256 internal constant ROLLING_SEASONS_ABOVE_PEG_CAP = 12;
    uint256 internal constant ROLLING_SEASONS_ABOVE_PEG_RATE = 1;

    // New fields for convert down penalty gauge
    uint256 internal constant INIT_BEANS_MINTED_ABOVE_PEG = 0;
    uint256 internal constant INIT_PERCENT_SUPPLY_THRESHOLD = 0;
    // 1%/24 = 0.01/24 ≈ 0.0004166667 = 4.1666667e14 (18 decimals)
    uint256 internal constant PERCENT_SUPPLY_THRESHOLD_RATE = 4166666666666667; // ~0.000416667 with 18 decimals
    bool internal constant INIT_CROSSED_BELOW_VT = false;
    uint256 internal constant CONVERT_DOWN_PENALTY_RATE = 1.0005e6;

    function init() external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Update the convertDownPenaltyGauge with new data structure
        Gauge memory convertDownPenaltyGauge = Gauge(
            abi.encode(
                LibGaugeHelpers.ConvertDownPenaltyValue({
                    penaltyRatio: INIT_CONVERT_DOWN_PENALTY_RATIO,
                    rollingSeasonsAbovePeg: INIT_ROLLING_SEASONS_ABOVE_PEG
                })
            ),
            address(this),
            IGaugeFacet.convertDownPenaltyGauge.selector,
            abi.encode(
                LibGaugeHelpers.ConvertDownPenaltyData({
                    rollingSeasonsAbovePegRate: ROLLING_SEASONS_ABOVE_PEG_RATE,
                    rollingSeasonsAbovePegCap: ROLLING_SEASONS_ABOVE_PEG_CAP,
                    beansMintedAbovePeg: INIT_BEANS_MINTED_ABOVE_PEG,
                    percentSupplyThreshold: INIT_PERCENT_SUPPLY_THRESHOLD,
                    percentSupplyThresholdRate: PERCENT_SUPPLY_THRESHOLD_RATE,
                    crossedBelowVt: INIT_CROSSED_BELOW_VT
                })
            )
        );
        LibGaugeHelpers.updateGauge(GaugeId.CONVERT_DOWN_PENALTY, convertDownPenaltyGauge);

        // Update the convertDownPenaltyRate
        s.sys.extEvaluationParameters.convertDownPenaltyRate = CONVERT_DOWN_PENALTY_RATE;
    }
}
