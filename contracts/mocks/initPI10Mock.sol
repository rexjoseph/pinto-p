/*
 SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.20;
import "contracts/libraries/LibAppStorage.sol";
import {LibGauge} from "contracts/libraries/LibGauge.sol";
import {LibGaugeHelpers} from "contracts/libraries/LibGaugeHelpers.sol";
import {GaugeId} from "contracts/beanstalk/storage/System.sol";

/**
 * @title InitPI10Mock
 * @dev Initializes parameters for pinto improvement 10.
 **/
contract InitPI10Mock {
    function init() external {
        initCultivationFactorGaugeV1_1();
    }

    // temps at season 4980
    uint256 internal constant CULTIVATION_TEMP = 748.5e6;
    uint256 internal constant PREV_SEASON_TEMP = 748.5e6;

    function initCultivationFactorGaugeV1_1() internal {
        (uint256 minDeltaCf, uint256 maxDeltaCf, uint256 minCf, uint256 maxCf) = abi.decode(
            LibGaugeHelpers.getGaugeData(GaugeId.CULTIVATION_FACTOR),
            (uint256, uint256, uint256, uint256)
        );

        // updates the gauge data to the new version, with the cultivation temperature and previous season temperature set on initialization.
        LibGaugeHelpers.updateGaugeData(
            GaugeId.CULTIVATION_FACTOR,
            abi.encode(minDeltaCf, maxDeltaCf, minCf, maxCf, CULTIVATION_TEMP, PREV_SEASON_TEMP)
        );
    }
}
