// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import {IMockFBeanstalk} from "contracts/interfaces/IMockFBeanstalk.sol";
import {TestHelper, C} from "test/foundry/utils/TestHelper.sol";
import {GaugeId} from "contracts/beanstalk/storage/System.sol";
import "forge-std/console.sol";
import {LibTransfer} from "contracts/libraries/Token/LibTransfer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibGaugeHelpers} from "contracts/libraries/LibGaugeHelpers.sol";

/**
 * @dev forks base and tests different cultivation factor scenarios
 * PI-11 adds the convert down penalty v1.2, and dewhitelists the WSOL and WETH pool.
 **/
contract Pi11ForkTest is TestHelper {
    function setUp() public {
        // fork a recent block, above the value target
        uint256 forkBlock = 33385717;
        vm.createSelectFork(vm.envString("BASE_RPC"), forkBlock - 1);

        // upgrade to PI11
        forkMainnetAndUpgradeAllFacets(forkBlock, vm.envString("BASE_RPC"), PINTO, "InitPI11");
    }

    function test_forkBase_pi11_values() public {
        bs = IMockFBeanstalk(PINTO);
        // verify that the convert down penalty gauge is initialized correctly
        LibGaugeHelpers.ConvertDownPenaltyData memory gd = abi.decode(
            bs.getGaugeData(GaugeId.CONVERT_DOWN_PENALTY),
            (LibGaugeHelpers.ConvertDownPenaltyData)
        );

        assertEq(gd.rollingSeasonsAbovePegRate, 1);
        assertEq(gd.rollingSeasonsAbovePegCap, 12);
        assertEq(gd.beansMintedAbovePeg, 0);
        assertEq(gd.beanMintedThreshold, 15_252_437e6);
        assertEq(gd.runningThreshold, 0);
        assertEq(gd.percentSupplyThresholdRate, 416666666666667);
        assertEq(gd.convertDownPenaltyRate, 1.005e6);
        assertEq(gd.thresholdSet, true);
    }

    // verify that the convert down penalty is applied correctly
    function test_forkBase_pi11_convertDownPenalty() public {
        bs = IMockFBeanstalk(PINTO);
        address[] memory whitelistedPools = bs.getWhitelistedLpTokens();
        // verify that the convert down penalty is applied correctly
        for (uint256 i = 0; i < whitelistedPools.length; i++) {
            address pool = whitelistedPools[i];
            uint256 amountIn = bs.getMaxAmountInAtRate(L2_PINTO, pool, 1.005e6);
            uint256 amountInMax = bs.getMaxAmountIn(L2_PINTO, pool);
            console.log("pool", pool);
            console.log("amountIn", amountIn);
            console.log("amountInMax", amountInMax);
        }
    }
}
