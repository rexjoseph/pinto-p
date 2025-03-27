// // SPDX-License-Identifier: MIT
// pragma solidity >=0.6.0 <0.9.0;
// pragma abicoder v2;

// import {IMockFBeanstalk} from "contracts/interfaces/IMockFBeanstalk.sol";
// import {TestHelper} from "test/foundry/utils/TestHelper.sol";
// import {PriceManipulation} from "contracts/ecosystem/PriceManipulation.sol";
// import {console} from "forge-std/console.sol";

// contract PriceManipulationTest is TestHelper {
//     PriceManipulation manipulation;
//     address[] operators;

//     function setUp() public {
//         vm.createSelectFork(vm.envString("BASE_RPC"));

//         initializeBeanstalkTestState(true, false);
//         bs = IMockFBeanstalk(PINTO);
//     }

//     function test_priceFirstBlock() public {
//         // First block after sPinto deployment.
//         forkFromBlock(27068608 + 1);
//         uint256 usdcPerSPinto = manipulation.price();
//         console.log("usdcPerSPinto", usdcPerSPinto);
//         assertApproxEqRel(usdcPerSPinto, 0.968e24, 0.001e18);
//     }

//     // function test_priceBelowPeg() public {
//     //     uint256 usdcPerSPinto;

//     //     // Below peg season.
//     //     forkFromSeason(2920);
//     //     usdcPerSPinto = manipulation.price();
//     //     console.log("usdcPerSPinto", usdcPerSPinto);
//     //     assertApproxEqRel(usdcPerSPinto, 0.734e24, 0.01e18);
//     // }

//     // function test_priceAbovePeg() public {
//     //     uint256 usdcPerSPinto;

//     //     // Above peg season.
//     //     forkFromSeason(2469);
//     //     usdcPerSPinto = manipulation.price();
//     //     console.log("usdcPerSPinto", usdcPerSPinto);
//     //     assertApproxEqRel(usdcPerSPinto, 1.001e24, 0.001e18);
//     // }

//     // function test_priceAtKnownSeason() public {
//     //     // Recent season.
//     //     forkFromBlock(28097567);
//     //     uint256 usdcPerSPinto = manipulation.price();
//     //     console.log("usdcPerSPinto", usdcPerSPinto);
//     //     assertApproxEqRel(usdcPerSPinto, 0.7883e24, 0.001e18);
//     // }

//     function forkFromSeason(uint256 season) private {
//         uint256 seasonDiff = bs.season() - season;
//         uint256 blockDiff = (seasonDiff * 60 * 60) / 2;
//         uint256 forkBlock = (block.number - blockDiff) - ((block.number - blockDiff) % 1800);
//         forkFromBlock(forkBlock);
//     }

//     function forkFromBlock(uint256 forkBlock) private {
//         console.log("forking from block", forkBlock);
//         vm.createSelectFork(vm.envString("BASE_RPC"), forkBlock);
//         forkMainnetAndUpgradeAllFacets(forkBlock, vm.envString("BASE_RPC"), PINTO);

//         // Update oracle timeouts to ensure they're not stale
//         updateOracleTimeouts(L2_PINTO, false);

//         manipulation = new PriceManipulation(PINTO);
//     }
// }
