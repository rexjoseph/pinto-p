/*
 SPDX-License-Identifier: MIT
*/

pragma solidity ^0.8.20;
import "../../libraries/LibAppStorage.sol";
import {LibUpdate} from "../../libraries/LibUpdate.sol";
import {Weather} from "../facets/sun/abstract/Weather.sol";
/**
 * @title InitPI8
 * @dev Updates parameters for pinto improvement 8.
 **/
contract InitPI8 {
    uint256 internal constant MIN_SOIL_SOWN_DEMAND = 5e6; // 5

    function init() external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Update min soil sown demand.
        s.sys.extEvaluationParameters.minSoilSownDemand = MIN_SOIL_SOWN_DEMAND;
        emit LibUpdate.UpdatedExtEvaluationParameters(
            s.sys.season.current,
            s.sys.extEvaluationParameters
        );

        // increase max crop ratio to 200%
        s.sys.evaluationParameters.maxBeanMaxLpGpPerBdvRatio = 2e18;
        emit LibUpdate.UpdatedEvaluationParameters(
            s.sys.season.current,
            s.sys.evaluationParameters
        );

        // get current crop scalar
        uint256 currentCropScalar = s.sys.seedGauge.beanToMaxLpGpPerBdvRatio;

        // change crop scalar to 66% (50% + 1.5*(66%) = 150%)
        s.sys.seedGauge.beanToMaxLpGpPerBdvRatio = 66e18;
        emit Weather.BeanToMaxLpGpPerBdvRatioChange(
            s.sys.season.current,
            type(uint256).max,
            -int80(int256(currentCropScalar - s.sys.seedGauge.beanToMaxLpGpPerBdvRatio))
        );
    }
}
