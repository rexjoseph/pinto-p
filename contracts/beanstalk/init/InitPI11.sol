/*
 SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.20;
import {AppStorage, LibAppStorage} from "../../libraries/LibAppStorage.sol";
import {Gauge, GaugeId} from "contracts/beanstalk/storage/System.sol";
import {LibGaugeHelpers} from "../../libraries/LibGaugeHelpers.sol";
import {IGaugeFacet} from "contracts/beanstalk/facets/sun/GaugeFacet.sol";
import {LibUpdate} from "../../libraries/LibUpdate.sol";

/**
 * @title InitPI11
 * @dev Initializes parameters for pinto improvement 11.
 * Updates the convert down penalty gauge to include new fields.
 **/
contract InitPI11 {
    // Original values for convert down penalty gauge.
    uint256 internal constant INIT_CONVERT_DOWN_PENALTY_RATIO = 0;
    uint256 internal constant INIT_ROLLING_SEASONS_ABOVE_PEG = 0;
    uint256 internal constant ROLLING_SEASONS_ABOVE_PEG_CAP = 12;
    uint256 internal constant ROLLING_SEASONS_ABOVE_PEG_RATE = 1;

    // New fields for convert down penalty gauge
    uint256 internal constant INIT_BEANS_MINTED_ABOVE_PEG = 0;
    uint256 internal constant PERCENT_SUPPLY_THRESHOLD_RATE = 416666666666667; // 1%/24 = 0.01e18/24 ≈ 0.0004166667e18
    uint256 internal constant INIT_BEAN_AMOUNT_ABOVE_THRESHOLD = 15_252_437e6; // calculation from XXX.
    uint256 internal constant INIT_RUNNING_THRESHOLD = 0; // initialize running threshold to 0
    uint256 internal constant CONVERT_DOWN_PENALTY_RATE = 1.005e6; // $1.005 convert price.

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
                    beanMintedThreshold: INIT_BEAN_AMOUNT_ABOVE_THRESHOLD,
                    runningThreshold: INIT_RUNNING_THRESHOLD,
                    percentSupplyThresholdRate: PERCENT_SUPPLY_THRESHOLD_RATE,
                    convertDownPenaltyRate: CONVERT_DOWN_PENALTY_RATE,
                    thresholdSet: true
                })
            )
        );
        LibGaugeHelpers.updateGauge(GaugeId.CONVERT_DOWN_PENALTY, convertDownPenaltyGauge);
    }
}
