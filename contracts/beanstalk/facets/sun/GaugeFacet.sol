/*
 * SPDX-License-Identifier: MIT
 */

pragma solidity ^0.8.20;

import {GaugeDefault} from "./abstract/GaugeDefault.sol";
import {Decimal} from "contracts/libraries/Decimal.sol";
import {LibEvaluate} from "contracts/libraries/LibEvaluate.sol";
import {ReentrancyGuard} from "contracts/beanstalk/ReentrancyGuard.sol";
import {C} from "contracts/C.sol";
import {LibDiamond} from "contracts/libraries/LibDiamond.sol";
import {LibGaugeHelpers} from "contracts/libraries/LibGaugeHelpers.sol";
import {Gauge, GaugeId} from "contracts/beanstalk/storage/System.sol";
import {PRBMathUD60x18} from "@prb/math/contracts/PRBMathUD60x18.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LibWhitelistedTokens} from "contracts/libraries/Silo/LibWhitelistedTokens.sol";
import {LibTokenSilo} from "contracts/libraries/Silo/LibTokenSilo.sol";
import {console} from "forge-std/console.sol";

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

    function cultivationFactor(
        bytes memory value,
        bytes memory systemData,
        bytes memory gaugeData
    ) external view returns (bytes memory result);

    function convertDownPenaltyGauge(
        bytes memory value,
        bytes memory,
        bytes memory gaugeData
    ) external view returns (bytes memory, bytes memory);

    function convertUpBonusGauge(
        bytes memory value,
        bytes memory systemData,
        bytes memory gaugeData
    ) external view returns (bytes memory, bytes memory);
}

/**
 * @notice GaugeFacet is a facet that contains the logic for all gauges in Beanstalk.
 * as well as adding, replacing, and removing Gauges.
 */
contract GaugeFacet is GaugeDefault, ReentrancyGuard {
    using LibGaugeHelpers for LibGaugeHelpers.ConvertBonusGaugeData;

    uint256 internal constant PRICE_PRECISION = 1e6;

    /**
     * @notice cultivationFactor is a gauge implementation that returns the adjusted cultivationFactor based on the podRate and the price of Pinto.
     */
    function cultivationFactor(
        bytes memory value,
        bytes memory systemData,
        bytes memory gaugeData
    ) external view returns (bytes memory, bytes memory) {
        uint256 currentValue = abi.decode(value, (uint256));
        LibEvaluate.BeanstalkState memory bs = abi.decode(systemData, (LibEvaluate.BeanstalkState));

        // if the price is 0, return the current value.
        if (bs.largestLiquidWellTwapBeanPrice == 0) {
            return (value, gaugeData);
        }

        // clamp the price to 1e6, to prevent overflows.
        if (bs.largestLiquidWellTwapBeanPrice > PRICE_PRECISION) {
            bs.largestLiquidWellTwapBeanPrice = PRICE_PRECISION;
        }

        (
            uint256 minDeltaCultivationFactor,
            uint256 maxDeltaCultivationFactor,
            uint256 minCultivationFactor,
            uint256 maxCultivationFactor
        ) = abi.decode(gaugeData, (uint256, uint256, uint256, uint256));

        // determine increase or decrease based on demand for soil.
        bool soilSoldOut = s.sys.weather.lastSowTime < type(uint32).max;
        // determine amount change as a function of podRate.
        uint256 amountChange = LibGaugeHelpers.linearInterpolation(
            bs.podRate.value,
            false,
            s.sys.evaluationParameters.podRateLowerBound,
            s.sys.evaluationParameters.podRateUpperBound,
            minDeltaCultivationFactor,
            maxDeltaCultivationFactor
        );
        // update the change based on price.
        amountChange = (amountChange * bs.largestLiquidWellTwapBeanPrice) / PRICE_PRECISION;

        // if soil did not sell out, inverse the amountChange.
        if (!soilSoldOut) {
            amountChange = 1e12 / amountChange;
        }

        // return the new cultivationFactor.
        // return unchanged gaugeData.
        return (
            abi.encode(
                LibGaugeHelpers.linear(
                    int256(currentValue),
                    soilSoldOut,
                    amountChange,
                    int256(minCultivationFactor),
                    int256(maxCultivationFactor)
                )
            ),
            gaugeData
        );
    }

    /**
     * @notice Tracks the down convert penalty ratio and the rolling count of seasons above peg.
     * Penalty ratio is the % of grown stalk lost on a down convert (1e18 = 100% penalty).
     * value is encoded as (uint256, uint256):
     *     penaltyRatio - the penalty ratio.
     *     rollingSeasonsAbovePeg - the rolling count of seasons above peg.
     * gaugeData encoded as (uint256, uint256):
     *     rollingSeasonsAbovePegRate - amount to change the the rolling count by each season.
     *     rollingSeasonsAbovePegCap - upper limit of rolling count.
     * @dev returned penalty ratio has 18 decimal precision.
     */
    function convertDownPenaltyGauge(
        bytes memory value,
        bytes memory systemData,
        bytes memory gaugeData
    ) external view returns (bytes memory, bytes memory) {
        LibEvaluate.BeanstalkState memory bs = abi.decode(systemData, (LibEvaluate.BeanstalkState));
        (uint256 rollingSeasonsAbovePegRate, uint256 rollingSeasonsAbovePegCap) = abi.decode(
            gaugeData,
            (uint256, uint256)
        );

        (uint256 penaltyRatio, uint256 rollingSeasonsAbovePeg) = abi.decode(
            value,
            (uint256, uint256)
        );
        rollingSeasonsAbovePeg = uint256(
            LibGaugeHelpers.linear(
                int256(rollingSeasonsAbovePeg),
                bs.twaDeltaB > 0 ? true : false,
                rollingSeasonsAbovePegRate,
                0,
                int256(rollingSeasonsAbovePegCap)
            )
        );

        // Do not update penalty ratio if l2sr failed to compute.
        if (bs.lpToSupplyRatio.value == 0) {
            return (abi.encode(penaltyRatio, rollingSeasonsAbovePeg), gaugeData);
        }

        // Scale L2SR by the optimal L2SR.
        uint256 l2srRatio = (1e18 * bs.lpToSupplyRatio.value) /
            s.sys.evaluationParameters.lpToSupplyRatioOptimal;

        uint256 timeRatio = (1e18 * PRBMathUD60x18.log2(rollingSeasonsAbovePeg * 1e18 + 1e18)) /
            PRBMathUD60x18.log2(rollingSeasonsAbovePegCap * 1e18 + 1e18);

        penaltyRatio = Math.min(1e18, (l2srRatio * (1e18 - timeRatio)) / 1e18);
        return (abi.encode(penaltyRatio, rollingSeasonsAbovePeg), gaugeData);
    }

    /**
     * @notice Calculates the stalk per pdv the protocol is willing to issue along with the
     * correspoinding pdv capacity.
     * ----------------------------------------------------------------
     * @return value
     *  The gauge value is encoded as (uint256, uint256, uint256, uint256):
     *     - seasonsBelowPeg - the rolling count of seasons below peg.
     *     - convertBonusFactor - the convert bonus ratio.
     *     - convertCapacityFactor - the convert bonus bdv capacity factor.
     *     - bonusStalkPerBdv - the bonus stalk per bdv to issue for converts.
     * @return gaugeData
     *  The gaugeData are ecoded as a struct of type LibGaugeHelpers.ConvertBonusGaugeData:
     *     - deltaC - the delta used in adjusting convertBonusFactor.
     *     - deltaT - the delta used in adjusting the convert bonus bdv capacity factor.
     *     - minConvertBonusFactor - the minimum value of the conversion factor (0).
     *     - maxConvertBonusFactor - the maximum value of the conversion factor (1e18).
     *     - minCapacityFactor - the minimum value of the convert bonus bdv capacity factor.
     *     - maxCapacityFactor - the maximum value of the convert bonus bdv capacity factor.
     *     - lastSeasonBdvConverted - amount of bdv converted last season.
     *     - thisSeasonBdvConverted - amount of bdv converted this season.
     */
    function convertUpBonusGauge(
        bytes memory value,
        bytes memory systemData,
        bytes memory gaugeData
    ) external view returns (bytes memory, bytes memory) {
        LibEvaluate.BeanstalkState memory bs = abi.decode(systemData, (LibEvaluate.BeanstalkState));

        // Decode current convert bonus ratio value and rolling count of seasons below peg
        (
            uint256 seasonsBelowPeg,
            uint256 convertBonusFactor,
            uint256 convertCapacityFactor,
            uint256 bonusStalkPerBdv,
            uint256 convertCapacity
        ) = abi.decode(value, (uint256, uint256, uint256, uint256, uint256));

        // Decode gauge data using the struct
        LibGaugeHelpers.ConvertBonusGaugeData memory gd = abi.decode(
            gaugeData,
            (LibGaugeHelpers.ConvertBonusGaugeData)
        );

        // reset the gaugeData
        // (i.e. set the amount converted last season to the amount converted this
        // season and set the amount converted this season to 0)
        gd.lastSeasonBdvConverted = gd.thisSeasonBdvConverted;
        gd.thisSeasonBdvConverted = 0;
        bytes memory newGaugeData = abi.encode(gd);

        // If twaDeltaB > 0 (above peg), reset values to 0
        if (bs.twaDeltaB > 0) {
            console.log("twaDeltaB > 0, reset convertBonusFactor and seasonsBelowPeg to 0");
            return (abi.encode(0, 0, 0, 0, 0), newGaugeData);
        }

        // If seasonsBelowPeg < 12, convertBonusFactor is 0 but seasonsBelowPeg increases
        // todo: make 12 an evaluation parameter
        if (bs.twaDeltaB <= 0 && seasonsBelowPeg < 12) {
            console.log("twaDeltaB <= 0 and seasonsBelowPeg < 12, increase seasonsBelowPeg by 1");
            return (abi.encode(seasonsBelowPeg + 1, 0, 0, 0, 0), newGaugeData);
        }

        // twaDeltaB <= 0 (below peg) && seasonsBelowPeg >= 12, ready to modify convertBonusFactor
        // and set convert bonus pdv capacity
        console.log("--------------------------------");
        console.log("twaDeltaB <= 0 and seasonsBelowPeg >= 12, ready to modify convertBonusFactor");

        // 1. determine C, the conversion factor, aka the stalkPerBdv scalar
        // 2. determine T, the convert bonus bdv capacity factor aka the deltaB scalar

        bool shouldIncrease;
        if (gd.thisSeasonBdvConverted == 0) {
            // no bdv converted this season, we should increase the bonus and limit capacity
            shouldIncrease = true;
        } else if (gd.lastSeasonBdvConverted == 0) {
            // no bdv was converted in the previous season but some was converted in the current season,
            // we should decrease bonus and increase capacity
            shouldIncrease = false;
        } else {
            uint256 pdvRatio = (gd.thisSeasonBdvConverted * C.PRECISION) /
                gd.lastSeasonBdvConverted;
            // if the pdv ratio resides within a range, do nothing:
            if (pdvRatio >= 0.95e18 && pdvRatio <= 1.05e18) {
                return (
                    abi.encode(
                        seasonsBelowPeg + 1,
                        convertBonusFactor,
                        convertCapacityFactor,
                        bonusStalkPerBdv,
                        convertCapacity
                    ),
                    newGaugeData
                );
            } else {
                // For convertBonusFactor, increase when pdvRatio decreases (<0.95)
                // Opposite behavior for convertCapacityFactor
                shouldIncrease = pdvRatio < 0.95e18;
            }
        }

        // increase/decrease convertBonusFactor via the linear function
        convertBonusFactor = uint256(
            LibGaugeHelpers.linear(
                int256(convertBonusFactor),
                shouldIncrease,
                gd.deltaC,
                int256(gd.minConvertBonusFactor),
                int256(gd.maxConvertBonusFactor)
            )
        );

        // increase/decrease convertCapacityFactor via the linear function (opposite behavior)
        convertCapacityFactor = uint256(
            LibGaugeHelpers.linear(
                int256(convertCapacityFactor),
                !shouldIncrease,
                gd.deltaT,
                int256(gd.minCapacityFactor),
                int256(gd.maxCapacityFactor)
            )
        );

        console.log("new convertBonusFactor: ", convertBonusFactor);
        console.log("new convertCapacityFactor: ", convertCapacityFactor);

        return (
            abi.encode(
                seasonsBelowPeg + 1,
                convertBonusFactor,
                convertCapacityFactor,
                getCurrentBonusStalkPerBdv(),
                ((uint256(-bs.twaDeltaB) * convertCapacityFactor) / C.PRECISION)
            ),
            newGaugeData
        );
    }

    /**
     * @notice Gets the bonus stalk per bdv for the current season.
     * @dev The stalkPerPDV is determined by taking the difference between the current stem tip
     * and the stemTip at a peg cross, and choosing the smallest amongst all whitelisted lp tokens.
     * This way the bonus cannot be gamed since someone could withdraw, deposit and convert without losing stalk.
     * @return stalkPerBdv The bonus stalk per bdv for the current season.
     */
    function getCurrentBonusStalkPerBdv() internal view returns (uint256) {
        // get stem tips for all whitelisted lp tokens and get the min
        address[] memory lpTokens = LibWhitelistedTokens.getWhitelistedLpTokens();
        uint96 stalkPerBdv = type(uint96).max;
        for (uint256 i = 0; i < lpTokens.length; i++) {
            int96 currentStemTip = LibTokenSilo.stemTipForToken(lpTokens[i]);
            uint96 tokenStalkPerBdv = uint96(
                currentStemTip - s.sys.belowPegCrossStems[lpTokens[i]]
            );
            if (tokenStalkPerBdv < stalkPerBdv) stalkPerBdv = tokenStalkPerBdv;
        }
        return uint256(stalkPerBdv);
    }

    /// GAUGE ADD/REMOVE/UPDATE ///

    // function addGauge(GaugeId gaugeId, Gauge memory gauge) external {
    //     LibDiamond.enforceIsContractOwner();
    //     LibGaugeHelpers.addGauge(gaugeId, gauge);
    // }

    // function removeGauge(GaugeId gaugeId) external {
    //     LibDiamond.enforceIsContractOwner();
    //     LibGaugeHelpers.removeGauge(gaugeId);
    // }

    // function updateGauge(GaugeId gaugeId, Gauge memory gauge) external {
    //     LibDiamond.enforceIsContractOwner();
    //     LibGaugeHelpers.updateGauge(gaugeId, gauge);
    // }

    function getGauge(GaugeId gaugeId) external view returns (Gauge memory) {
        return s.sys.gaugeData.gauges[gaugeId];
    }

    function getGaugeValue(GaugeId gaugeId) external view returns (bytes memory) {
        return s.sys.gaugeData.gauges[gaugeId].value;
    }

    function getGaugeData(GaugeId gaugeId) external view returns (bytes memory) {
        return s.sys.gaugeData.gauges[gaugeId].data;
    }

    // /**
    //  * @notice returns the result of calling a gauge.
    //  */
    // function getGaugeResult(
    //     Gauge memory gauge,
    //     bytes memory systemData
    // ) external returns (bytes memory, bytes memory) {
    //     return LibGaugeHelpers.getGaugeResult(gauge, systemData);
    // }

    // /**
    //  * @notice returns the result of calling a gauge by its id.
    //  */
    // function getGaugeIdResult(
    //     GaugeId gaugeId,
    //     bytes memory systemData
    // ) external returns (bytes memory, bytes memory) {
    //     Gauge memory g = s.sys.gaugeData.gauges[gaugeId];
    //     return LibGaugeHelpers.getGaugeResult(g, systemData);
    // }
}
