// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import {IMockFBeanstalk} from "contracts/interfaces/IMockFBeanstalk.sol";
import {TestHelper} from "test/foundry/utils/TestHelper.sol";
import {PriceManipulation} from "contracts/ecosystem/PriceManipulation.sol";
import {console} from "forge-std/console.sol";

contract PriceManipulationTest is TestHelper {
    PriceManipulation manipulation;
    address[] operators;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC"));

        initializeBeanstalkTestState(true, false);
        bs = IMockFBeanstalk(PINTO);

        // // uint256 forkBlock = 27218527; // season 2546
        // // uint256 forkBlock = 26045631; // season 2534
        // // uint256 forkBlock = 28091021; // season 3030 - $0.7854, 1.273236
        // uint256 forkBlock = getBlockFromSeason(3030);
        // console.log("forkBlock", forkBlock);

        // // Fork at target block.
        // vm.createSelectFork(vm.envString("BASE_RPC"), forkBlock);
        // forkMainnetAndUpgradeAllFacets(forkBlock, vm.envString("BASE_RPC"), PINTO);

        // // Update oracle timeouts to ensure they're not stale
        // updateOracleTimeouts(L2_PINTO, false);

        // // go forward to season 2547
        // vm.roll(forkBlock + 10);
        // vm.warp(block.timestamp + 10 seconds);
        // bs.sunrise();
    }

    function test_price() public {
        uint256 usdcPerSPinto;

        // First block after sPinto deployment.
        forkFromBlock(27068608 + 1);
        usdcPerSPinto = manipulation.price();
        console.log("usdcPerSPinto", usdcPerSPinto);
        assertApproxEqRel(usdcPerSPinto, 0.968e24, 0.001e18);

        // // Below peg season.
        // forkFromSeason(2920);
        // usdcPerSPinto = manipulation.price();
        // console.log("usdcPerSPinto", usdcPerSPinto);
        // assertApproxEqRel(usdcPerSPinto, 0.734e24, 0.01e18);

        // // Above peg season.
        // forkFromSeason(2469);
        // usdcPerSPinto = manipulation.price();
        // console.log("usdcPerSPinto", usdcPerSPinto);
        // assertApproxEqRel(usdcPerSPinto, 1.001e24, 0.001e18);

        // // Recent season.
        // forkFromBlock(28097567);
        // usdcPerSPinto = manipulation.price();
        // console.log("usdcPerSPinto", usdcPerSPinto);
        // assertApproxEqRel(usdcPerSPinto, 0.7883e24, 0.001e18);
    }

    function forkFromSeason(uint256 season) private {
        uint256 seasonDiff = bs.season() - season;
        uint256 blockDiff = (seasonDiff * 60 * 60) / 2;
        uint256 forkBlock = (block.number - blockDiff) - ((block.number - blockDiff) % 1800);
        forkFromBlock(forkBlock);
    }

    function forkFromBlock(uint256 forkBlock) private {
        console.log("forking from block", forkBlock);
        vm.createSelectFork(vm.envString("BASE_RPC"), forkBlock);
        forkMainnetAndUpgradeAllFacets(forkBlock, vm.envString("BASE_RPC"), PINTO);

        // Update oracle timeouts to ensure they're not stale
        updateOracleTimeouts(L2_PINTO, false);

        manipulation = new PriceManipulation(PINTO);
    }
}
