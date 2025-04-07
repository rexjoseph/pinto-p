/*
 SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.20;
import "../../libraries/LibAppStorage.sol";
import {Gauge, GaugeId} from "contracts/beanstalk/storage/System.sol";
import {LibGaugeHelpers} from "../../libraries/LibGaugeHelpers.sol";
import {IGaugeFacet} from "contracts/beanstalk/facets/sun/GaugeFacet.sol";

/**
 * @title InitPI8
 * @dev Initializes parameters for pinto improvement 8.
 **/
contract InitPI9 {
    // Gauge values
    uint256 internal constant INIT_SEASONS_BELOW_PEG = 0;
    uint256 internal constant INIT_CONVERT_BONUS_FACTOR = 0;
    uint256 internal constant INIT_CONVERT_CAPACITY_FACTOR = 0;
    uint256 internal constant INIT_BONUS_STALK_PER_BDV = 0;
    uint256 internal constant INIT_CONVERT_CAPACITY = 0;
    // Gauge data
    uint256 internal constant INIT_DELTA_C = 0.01e18;
    uint256 internal constant INIT_DELTA_T = 0.004e18;
    uint256 internal constant INIT_MIN_CONVERT_BONUS_FACTOR = 0;
    uint256 internal constant INIT_MAX_CONVERT_BONUS_FACTOR = 1e18;
    uint256 internal constant INIT_MIN_CAPACITY_FACTOR = 0.1e18; // 10% of deltab
    uint256 internal constant INIT_MAX_CAPACITY_FACTOR = 0.5e18; // 50% of deltab
    uint256 internal constant INIT_LAST_SEASON_BVD_CONVERTED = 0;
    uint256 internal constant INIT_THIS_SEASON_BVD_CONVERTED = 0;

    // gauge data
    //     struct ConvertBonusGaugeData {
    //     uint256 deltaC; // delta used in adjusting convertBonusFactor
    //     uint256 deltaT; // delta used in adjusting the convert bonus bdv capacity factor
    //     uint256 minConvertBonusFactor; // minimum value of the conversion factor
    //     uint256 maxConvertBonusFactor; // maximum value of the conversion factor
    //     uint256 minCapacityFactor; // minimum value of the convert bonus bdv capacity factor
    //     uint256 maxCapacityFactor; // maximum value of the convert bonus bdv capacity factor
    //     uint256 lastSeasonBdvConverted; // amount of bdv converted last season
    //     uint256 thisSeasonBdvConverted; // amount of bdv converted this season
    // }

    // gauge value
    // (
    //     uint256 seasonsBelowPeg,
    //     uint256 convertBonusFactor,
    //     uint256 convertCapacityFactor,
    //     uint256 bonusStalkPerBdv,
    //     uint256 convertCapacity
    // )

    function init() external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Initialize and add convertBonusGauge.
        Gauge memory convertBonusGauge = Gauge(
            abi.encode(
                INIT_SEASONS_BELOW_PEG,
                INIT_CONVERT_BONUS_FACTOR,
                INIT_CONVERT_CAPACITY_FACTOR,
                INIT_BONUS_STALK_PER_BDV,
                INIT_CONVERT_CAPACITY
            ),
            address(this),
            IGaugeFacet.convertUpBonusGauge.selector,
            abi.encode(
                INIT_DELTA_C,
                INIT_DELTA_T,
                INIT_MIN_CONVERT_BONUS_FACTOR,
                INIT_MAX_CONVERT_BONUS_FACTOR,
                INIT_MIN_CAPACITY_FACTOR,
                INIT_MAX_CAPACITY_FACTOR,
                INIT_LAST_SEASON_BVD_CONVERTED,
                INIT_THIS_SEASON_BVD_CONVERTED
            )
        );
        LibGaugeHelpers.addGauge(GaugeId.CONVERT_UP_BONUS, convertBonusGauge);
    }
}
