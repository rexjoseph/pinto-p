// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import {IMockFBeanstalk} from "contracts/interfaces/IMockFBeanstalk.sol";
import {TestHelper, C} from "test/foundry/utils/TestHelper.sol";
import {GaugeId} from "contracts/beanstalk/storage/System.sol";
import "forge-std/console.sol";
import {LibTransfer} from "contracts/libraries/Token/LibTransfer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev forks base and tests different cultivation factor scenarios
 * InitPI10Mock is used as the init facet to init the cultivation temperatures to 748.5e6 instead of 0
 **/
contract Pi10ForkTest is TestHelper {
    address farmer1 = makeAddr("farmer1");
    address farmer2 = makeAddr("farmer2");
    string constant CSV_PATH = "oscillation_data.csv";

    struct CultivationData {
        uint256 cultivationFactor;
        uint256 cultivationTemp;
        uint256 prevSeasonTemp;
    }

    function setUp() public {
        initializeBeanstalkTestState(true, false);
    }

    /////////////////// TEST FUNCTIONS ///////////////////

    function test_forkBase_cultivationFactor_noSow() public {
        bs = IMockFBeanstalk(PINTO);
        uint256 forkBlock = 31599727 - 1;
        forkMainnetAndUpgradeAllFacets(forkBlock, vm.envString("BASE_RPC"), PINTO, "InitPI10Mock");

        uint256 temperatureBeforeUpgrade = bs.weather().temp;
        advanceToNextSeason();

        CultivationData memory data = getCultivationData();

        assertEq(
            data.cultivationTemp,
            temperatureBeforeUpgrade,
            "cultivationTemp should be equal to the previous season temperature"
        );
        assertEq(
            data.prevSeasonTemp,
            temperatureBeforeUpgrade,
            "prevSeasonTemp should be the same as the temperature before upgrade"
        );
        assertEq(
            data.cultivationFactor,
            1e6,
            "cultivationFactor should be 1e6 (minimum cultivation factor)"
        );
    }

    function test_forkBase_cultivationFactor_oscillate_oneOrder() public {
        bs = IMockFBeanstalk(PINTO);
        uint256 forkBlock = 31599727 - 1;
        forkMainnetAndUpgradeAllFacets(forkBlock, vm.envString("BASE_RPC"), PINTO, "InitPI10Mock");

        uint256 temperatureBeforeUpgrade = bs.weather().temp;
        advanceToNextSeason();

        // 4 seasons of soil selling out, temp goes down to 745%
        uint256 cultivationFactorFlat;
        for (uint256 i = 0; i < 4; i++) {
            sowAll(farmer1);
            stepSeason();
            logSeasonData(i + 1);

            CultivationData memory data = getCultivationData();
            if (i == 3) cultivationFactorFlat = data.cultivationFactor;
        }

        // 2 seasons of no sowing, temp increases to 746%
        console.log("--------------------------------");
        console.log("2 seasons of soil not selling out, temp should be 745%");
        console.log("--------------------------------");

        for (uint256 i = 0; i < 2; i++) {
            stepSeason();
            logSeasonData(i + 1);

            CultivationData memory data = getCultivationData();
            assertEq(data.cultivationFactor, cultivationFactorFlat);
        }

        // Soil sells out again at 746%
        console.log("--------------------------------");
        console.log("Soil sells out again at 746%, cultivation factor should increase");
        console.log("--------------------------------");

        sowAll(farmer1);
        stepSeason();
        logSeasonData(1);

        CultivationData memory data = getCultivationData();
        assertGt(data.cultivationFactor, cultivationFactorFlat);
    }

    function test_forkBase_cultivationFactor_oscillate_twoOrders() public {
        bs = IMockFBeanstalk(PINTO);
        uint256 forkBlock = 31599727 - 1;
        forkMainnetAndUpgradeAllFacets(forkBlock, vm.envString("BASE_RPC"), PINTO, "InitPI10Mock");

        uint256 temperatureBeforeUpgrade = bs.weather().temp;
        advanceToNextSeason();

        // Initialize CSV file
        vm.writeFile(CSV_PATH, "step,season,prev_temp,cultivation_factor\n");

        // Step 1: Soil sells out above User1 limit order temp
        uint256 cultivationFactorFlat = runStep1();

        // Step 2: Oscillation between 739% and 740% temp for User1 limit order
        runStep2();

        // Step 3: User2 order makes cultivation factor decrease
        runStep3();

        // Step 4: Oscillation with User2 only
        runStep4();
    }

    /////////////////// HELPER FUNCTIONS ///////////////////

    //////////////// TWO ORDER SIMULATION ////////////////

    function runStep1() internal returns (uint256) {
        console.log("\n");
        console.log("==========================================");
        console.log("STEP 1: INITIAL SOIL SELLING");
        console.log("User1 sows all soil for 10 seasons");
        console.log("Temperature decreases to 739%");
        console.log("==========================================");
        console.log("\n");

        uint256 cultivationFactorFlat;
        for (uint256 i = 0; i < 10; i++) {
            sowAll(farmer1);
            stepSeason();
            logSeasonData(i + 1);

            CultivationData memory data = getCultivationData();
            writeToCSV("step1_user1_sow_all", data);

            if (i == 9) cultivationFactorFlat = data.cultivationFactor;
        }
        return cultivationFactorFlat;
    }

    function runStep2() internal {
        console.log("\n");
        console.log("==========================================");
        console.log("STEP 2: USER1 OSCILLATION PATTERN");
        console.log("Alternating between 2 seasons no sow and 1 season full sow");
        console.log("Temperature oscillates between 739% and 740%");
        console.log("==========================================");
        console.log("\n");

        for (uint256 i = 0; i < 3; i++) {
            // 2 seasons of no sowing
            for (uint256 j = 0; j < 2; j++) {
                stepSeason();
                logSeasonData(i * 3 + j + 1);

                CultivationData memory data = getCultivationData();
                writeToCSV("step2_user1_oscillation_no_sow", data);
            }

            // 1 season of full sowing
            sowAll(farmer1);
            stepSeason();
            logSeasonData(i * 3 + 3);

            CultivationData memory data = getCultivationData();
            writeToCSV("step2_user1_oscillation_full_sow", data);
        }
    }

    function runStep3() internal {
        console.log("\n");
        console.log("==========================================");
        console.log("STEP 3: USER2 INITIAL SOWING");
        console.log("User2 starts sowing at 737.5% temperature");
        console.log("Cultivation factor decreases until capacity is met");
        console.log("==========================================");
        console.log("\n");

        sowAmount(farmer2, 100e6);
        uint256 soilSownLastSeason = 100e6;
        stepSeason();

        for (uint256 i = 0; i < 3; i++) {
            soilSownLastSeason = sowIncreasing(farmer2, soilSownLastSeason);
            stepSeason();
            logSeasonData(i + 1);

            CultivationData memory data = getCultivationData();
            writeToCSV("step3_user2_some_sow_at_lower_temp", data);
        }
    }

    function runStep4() internal {
        console.log("\n");
        console.log("==========================================");
        console.log("STEP 4: USER2 OSCILLATION PATTERN");
        console.log("User2 alternates between selling out all soil and no sowing");
        console.log("Temperature oscillates around 737%");
        console.log("==========================================");
        console.log("\n");

        for (uint256 i = 0; i < 3; i++) {
            stepSeason();
            logSeasonData(i * 3 + 1);

            CultivationData memory data = getCultivationData();
            writeToCSV("step4_user2_oscillation", data);

            sowAll(farmer2);

            for (uint256 j = 0; j < 2; j++) {
                stepSeason();
                logSeasonData(i * 3 + j + 2);

                data = getCultivationData();
                writeToCSV("step4_user2_oscillation", data);
            }
        }
    }

    //////////////// UTILITY FUNCTIONS ////////////////

    function getCultivationData() internal view returns (CultivationData memory) {
        bytes memory cultivationFactorData = bs.getGaugeData(GaugeId.CULTIVATION_FACTOR);
        bytes memory cultivationFactorValue = bs.getGaugeValue(GaugeId.CULTIVATION_FACTOR);

        uint256 cultivationFactor = abi.decode(cultivationFactorValue, (uint256));

        (, , , , uint256 cultivationTemp, uint256 prevSeasonTemp) = abi.decode(
            cultivationFactorData,
            (uint256, uint256, uint256, uint256, uint256, uint256)
        );

        return CultivationData(cultivationFactor, cultivationTemp, prevSeasonTemp);
    }

    function logSeasonData(uint256 iteration) internal view {
        CultivationData memory data = getCultivationData();
        console.log("Season:", bs.season());
        console.log("Temperature:", bs.weather().temp);
        console.log("Cultivation Factor:", data.cultivationFactor);
        console.log("Cultivation Temperature:", data.cultivationTemp);
        console.log("Previous Season Temperature:", data.prevSeasonTemp);
        console.log("Total Soil:", bs.totalSoil());
        console.log("--------------------------------");
    }

    function writeToCSV(string memory step, CultivationData memory data) internal {
        string memory line = string.concat(
            step,
            ",",
            vm.toString(bs.season()),
            ",",
            vm.toString(data.prevSeasonTemp),
            ",",
            vm.toString(data.cultivationFactor)
        );
        vm.writeLine(CSV_PATH, line);
    }

    function advanceToNextSeason() internal {
        vm.roll(31599727 + 10);
        vm.warp(block.timestamp + 10 seconds);
        bs.sunrise();
    }

    function sowAll(address farmer) internal {
        uint256 soil = bs.totalSoil();
        deal(L2_PINTO, farmer, soil);
        vm.startPrank(farmer);
        IERC20(L2_PINTO).approve(address(bs), soil);
        bs.sow(soil, 0, uint8(LibTransfer.From.EXTERNAL));
        vm.stopPrank();
    }

    function sowIncreasing(address farmer, uint256 soilSownLastSeason) internal returns (uint256) {
        uint256 totalSoil = bs.totalSoil();
        uint256 soilToSow = soilSownLastSeason + ((soilSownLastSeason * 5.1e6) / 100e6);
        if (soilToSow > totalSoil) {
            soilToSow = totalSoil;
        }
        deal(L2_PINTO, farmer, soilToSow);
        vm.startPrank(farmer);
        IERC20(L2_PINTO).approve(address(bs), soilToSow);
        console.log("sowing soil: ", soilToSow);
        bs.sow(soilToSow, 0, uint8(LibTransfer.From.EXTERNAL));
        vm.stopPrank();
        return soilToSow;
    }

    function sowAmount(address farmer, uint256 amount) internal {
        deal(L2_PINTO, farmer, amount);
        vm.startPrank(farmer);
        IERC20(L2_PINTO).approve(address(bs), amount);
        bs.sow(amount, 0, uint8(LibTransfer.From.EXTERNAL));
        vm.stopPrank();
    }

    function stepSeason() internal {
        vm.warp(block.timestamp + 61 minutes);
        vm.roll(block.number + 1);
        bs.sunrise();
    }
}
