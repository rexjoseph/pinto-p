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
        initializeBeanstalkTestState(true, false);

        bs = IMockFBeanstalk(PINTO);

        // fork just before season 2546 (which happened in block 27218527)
        uint256 forkBlock = 27218527;

        // Fork base at seasonBlock+1
        vm.createSelectFork(vm.envString("BASE_RPC"), forkBlock - 1);
        forkMainnetAndUpgradeAllFacets(forkBlock - 1, vm.envString("BASE_RPC"), PINTO);

        // Update oracle timeouts to ensure they're not stale
        updateOracleTimeouts(L2_PINTO, false);

        // go forward to season 2547
        vm.roll(forkBlock + 10);
        vm.warp(block.timestamp + 10 seconds);
        // bs.sunrise();

        // // upon the first sunrise call of a well, the well cumulative reserves are initialized,
        // // and will not return a deltaB. We initialize the well cumulative reserves here.
        // // See: {LibWellMinting.capture}
        // season.initOracleForAllWhitelistedWells();

        // // chainlink oracles need to be initialized for the wells.
        // initializeChainlinkOraclesForWhitelistedWells();

        // vm.prank(BEANSTALK);
        // bs.updateOracleImplementationForToken(
        //     WETH,
        //     IMockFBeanstalk.Implementation(
        //         0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70,
        //         bytes4(0),
        //         bytes1(0x01),
        //         abi.encode(LibChainlinkOracle.FOUR_DAY_TIMEOUT)
        //     )
        // );
        // vm.prank(BEANSTALK);
        // bs.updateOracleImplementationForToken(
        //     CBETH,
        //     IMockFBeanstalk.Implementation(
        //         0xd7818272B9e248357d13057AAb0B417aF31E817d,
        //         bytes4(0),
        //         bytes1(0x01),
        //         abi.encode(LibChainlinkOracle.FOUR_DAY_TIMEOUT)
        //     )
        // );
        // vm.prank(BEANSTALK);
        // bs.updateOracleImplementationForToken(
        //     CBBTC,
        //     IMockFBeanstalk.Implementation(
        //         0x07DA0E54543a844a80ABE69c8A12F22B3aA59f9D,
        //         bytes4(0),
        //         bytes1(0x01),
        //         abi.encode(LibChainlinkOracle.FOUR_DAY_TIMEOUT)
        //     )
        // );
        // vm.prank(BEANSTALK);
        // bs.updateOracleImplementationForToken(
        //     USDC,
        //     IMockFBeanstalk.Implementation(
        //         0x7e860098F58bBFC8648a4311b374B1D669a2bc6B,
        //         bytes4(0),
        //         bytes1(0x01),
        //         abi.encode(LibChainlinkOracle.FOUR_DAY_TIMEOUT)
        //     )
        // );
        // vm.prank(BEANSTALK);
        // bs.updateOracleImplementationForToken(
        //     WSOL,
        //     IMockFBeanstalk.Implementation(
        //         0x975043adBb80fc32276CbF9Bbcfd4A601a12462D,
        //         bytes4(0),
        //         bytes1(0x01),
        //         abi.encode(LibChainlinkOracle.FOUR_DAY_TIMEOUT)
        //     )
        // );

        // warpToNextSeasonAndUpdateOracles();
        // vm.roll(block.number + 1800);
        // bs.sunrise();

        manipulation = new PriceManipulation(BEANSTALK);
    }

    function test_aggregateInstantPrice() public {
        uint256 usdcPerSPinto = manipulation.aggregateInstantPrice();
        console.log("usdcPerSPinto", usdcPerSPinto);
        assertGt(usdcPerSPinto, 0, "Price is zero");
    }
}
