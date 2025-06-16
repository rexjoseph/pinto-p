// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import {IMockFBeanstalk} from "contracts/interfaces/IMockFBeanstalk.sol";
import {TestHelper, C} from "test/foundry/utils/TestHelper.sol";
import {GaugeId} from "contracts/beanstalk/storage/System.sol";
import "forge-std/console.sol";
import {LibTransfer} from "contracts/libraries/Token/LibTransfer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pi10ForkTest is TestHelper {
    address farmer1 = makeAddr("farmer1");
    address farmer2 = makeAddr("farmer2");

    function setUp() public {
        initializeBeanstalkTestState(true, false);
    }

    /**
     * 1. Tests that if nothing is sown:
     * - Cultivation temp does not change
     * - Previous season temp changes to the previous temperature
     */
    function test_forkBase_cultivationFactor_noSow() public {
        bs = IMockFBeanstalk(PINTO);
        // fork just before season 4980,
        // twadeltab = ~ -205k
        // Pod Rate: 352%
        // temperature = 749%
        uint256 forkBlock = 31599727 - 1;

        // upgrade to PI9
        forkMainnetAndUpgradeAllFacets(forkBlock, vm.envString("BASE_RPC"), PINTO, "InitPI10");

        // get temp before upgrade
        uint256 temperatureBeforeUpgrade = bs.weather().temp;

        // go forward to season
        vm.roll(31599727 + 10);
        vm.warp(block.timestamp + 10 seconds);

        // call sunrise
        bs.sunrise();

        uint256 temperatureAfterUpgrade = bs.weather().temp;
        console.log("temperatureAfterUpgrade", temperatureAfterUpgrade);

        // get cultivation factor gauge
        (
            uint256 cultivationFactor,
            uint256 cultivationTemp,
            uint256 prevSeasonTemp
        ) = getCultivationFactorGauge(bs);

        assertEq(
            cultivationTemp,
            temperatureBeforeUpgrade,
            "cultivationTemp should be equal to the previous season temperature"
        );
        assertEq(
            prevSeasonTemp,
            temperatureBeforeUpgrade,
            "prevSeasonTemp should be the same as the temperature before upgrade"
        );
        assertEq(
            cultivationFactor,
            1e6,
            "cultivationFactor should be 1e6 (minimum cultivation factor)"
        );
    }

    /**
     * 2. Tests that if a user has a temperature limit order to sow as much as possible and the temperature goes down
     * below that threshold, the cultivation factor will not decrease, until the temperature goes
     * back up to the limit order temperature.
     */
    function test_forkBase_cultivationFactor_oscillate_oneOrder() public {
        bs = IMockFBeanstalk(PINTO);
        // fork just before season 4980,
        // twadeltab = ~ -205k
        // Pod Rate: 352%
        // temperature = 749%
        uint256 forkBlock = 31599727 - 1;

        // upgrade to PI9
        forkMainnetAndUpgradeAllFacets(forkBlock, vm.envString("BASE_RPC"), PINTO, "InitPI10");

        // get temp before upgrade
        uint256 temperatureBeforeUpgrade = bs.weather().temp;

        // go forward to season 4981
        vm.roll(31599727 + 10);
        vm.warp(block.timestamp + 10 seconds);
        // call sunrise
        bs.sunrise();

        // 4 seasons of soil selling out, temp goes down to 745%
        // We assume 746% is the limit order temperature of farmer 1 tractor order.
        uint256 cultivationFactorFlat;
        for (uint256 i = 0; i < 4; i++) {
            // sow all soil
            sowAll(farmer1);

            // call sunrise
            stepSeason();

            // log season number and temperature
            console.log("Iteration", i + 1);
            console.log("season", bs.season());
            console.log("temperature", bs.weather().temp);

            // get cultivation factor gauge
            (
                uint256 cultivationFactor,
                uint256 cultivationTemp,
                uint256 prevSeasonTemp
            ) = getCultivationFactorGauge(bs);

            console.log("cultivationFactor", cultivationFactor);
            console.log("cultivationTemp", cultivationTemp);
            console.log("prevSeasonTemp", prevSeasonTemp);
            console.log("soil", bs.totalSoil());
            console.log("-------------------");

            if (i == 3) cultivationFactorFlat = cultivationFactor;
        }

        // So after the 4 seasons pass, current temp < limit order temp so soil will not sell out.
        // After 2 seasons, temp increases back up to 746% (0.5% increase each season)
        console.log("--------------------------------");
        console.log("2 seasons of soil not selling out, temp should be 745%");
        console.log("--------------------------------");
        for (uint256 i = 0; i < 2; i++) {
            // call sunrise
            stepSeason();

            // log season number and temperature
            console.log("Iteration", i + 1);
            console.log("season", bs.season());
            console.log("temperature", bs.weather().temp);

            // get cultivation factor gauge
            (
                uint256 cultivationFactor,
                uint256 cultivationTemp,
                uint256 prevSeasonTemp
            ) = getCultivationFactorGauge(bs);

            console.log("cultivationFactor", cultivationFactor);
            console.log("cultivationTemp", cultivationTemp);
            console.log("prevSeasonTemp", prevSeasonTemp);
            console.log("soil", bs.totalSoil());
            console.log("-------------------");

            // assert cultivation factor is the same as the flat cultivation factor
            assertEq(cultivationFactor, cultivationFactorFlat);
        }

        // Soil sells out again at 746%
        // Cultivation factor should stay the same during the previous 2 seasons
        // And then increase again after soil sells out again.
        console.log("--------------------------------");
        console.log("Soil sells out again at 746%, cultivation factor should increase");
        console.log("--------------------------------");

        // sow all soil
        sowAll(farmer1);
        stepSeason();

        console.log("season", bs.season());
        console.log("temperature", bs.weather().temp);

        // get cultivation factor gauge
        (
            uint256 cultivationFactor,
            uint256 cultivationTemp,
            uint256 prevSeasonTemp
        ) = getCultivationFactorGauge(bs);

        console.log("cultivationFactor", cultivationFactor);
        console.log("cultivationTemp", cultivationTemp);
        console.log("prevSeasonTemp", prevSeasonTemp);
        console.log("soil", bs.totalSoil());
        console.log("-------------------");

        // assert cultivation factor is greater than the flat cultivation factor
        assertGt(cultivationFactor, cultivationFactorFlat);
    }

    function test_forkBase_cultivationFactor_oscillate_twoOrders() public {
        bs = IMockFBeanstalk(PINTO);
        // fork just before season 4980,
        // twadeltab = ~ -205k
        // Pod Rate: 352%
        // temperature = 749%
        uint256 forkBlock = 31599727 - 1;

        // upgrade to PI9
        forkMainnetAndUpgradeAllFacets(forkBlock, vm.envString("BASE_RPC"), PINTO, "InitPI10");

        // get temp before upgrade
        uint256 temperatureBeforeUpgrade = bs.weather().temp;

        // go forward to season 4981
        vm.roll(31599727 + 10);
        vm.warp(block.timestamp + 10 seconds);
        // call sunrise
        bs.sunrise();

        // Create CSV file with headers
        string memory csvPath = "oscillation_data.csv";
        vm.writeFile(csvPath, "step,season,prev_temp,cultivation_factor\n");

        ////////////////// STEP 1: SOIL SELLS OUT ABOVE USER1 LIMIT ORDER TEMP //////////////////

        // 10 seasons of soil selling out, temp goes down to 739%
        // We assume 740% is the limit order temperature of farmer 1 tractor order.
        uint256 cultivationFactorFlat;
        for (uint256 i = 0; i < 10; i++) {
            // sow all soil
            sowAll(farmer1);

            // call sunrise
            stepSeason();

            // log season number and temperature
            console.log("Iteration", i + 1);
            console.log("season", bs.season());
            console.log("temperature", bs.weather().temp);

            // get cultivation factor gauge
            (
                uint256 cultivationFactor,
                uint256 cultivationTemp,
                uint256 prevSeasonTemp
            ) = getCultivationFactorGauge(bs);

            // Write data to CSV
            string memory line = string.concat(
                "step1_user1_sow_all,",
                vm.toString(bs.season()),
                ",",
                vm.toString(prevSeasonTemp),
                ",",
                vm.toString(cultivationFactor)
            );
            vm.writeLine(csvPath, line);

            console.log("cultivationFactor", cultivationFactor);
            console.log("cultivationTemp", cultivationTemp);
            console.log("prevSeasonTemp", prevSeasonTemp);
            console.log("soil", bs.totalSoil());
            console.log("-------------------");

            if (i == 9) cultivationFactorFlat = cultivationFactor;
        }

        ////////////////// STEP 2: OSCILLATION BETWEEN 739% AND 740% TEMP FOR USER 1 LIMIT ORDER //////////////////

        // Temp oscilates between 739% and 740%.
        // When temp reaches 740%, soil sells out again due to the user's order.
        // Alternate between soil not selling out for 2 seasons and soil selling out for 1 season
        // Every time soil sells out, the cultivation factor will increase.
        console.log("--------------------------------");
        console.log("Alternating pattern: 2 seasons no sow, 1 season full sow");
        console.log("--------------------------------");

        for (uint256 i = 0; i < 3; i++) {
            // 2 seasons of no sowing
            console.log("2 seasons of no sowing");
            for (uint256 j = 0; j < 2; j++) {
                stepSeason();

                // log season number and temperature
                console.log("Iteration", i * 3 + j + 1);
                console.log("season", bs.season());
                console.log("temperature", bs.weather().temp);

                // get cultivation factor gauge
                (
                    uint256 cultivationFactor,
                    uint256 cultivationTemp,
                    uint256 prevSeasonTemp
                ) = getCultivationFactorGauge(bs);

                // Write data to CSV
                string memory line = string.concat(
                    "step2_user1_oscillation,",
                    vm.toString(bs.season()),
                    ",",
                    vm.toString(prevSeasonTemp),
                    ",",
                    vm.toString(cultivationFactor)
                );
                vm.writeLine(csvPath, line);

                console.log("cultivationFactor", cultivationFactor);
                console.log("cultivationTemp", cultivationTemp);
                console.log("prevSeasonTemp", prevSeasonTemp);
                console.log("soil", bs.totalSoil());
                console.log("-------------------");
            }

            // 1 season of full sowing
            console.log("1 season of full sowing");
            sowAll(farmer1);
            stepSeason();

            // log season number and temperature
            console.log("Iteration", i * 3 + 3);
            console.log("season", bs.season());
            console.log("temperature", bs.weather().temp);

            // get cultivation factor gauge
            (
                uint256 cultivationFactor,
                uint256 cultivationTemp,
                uint256 prevSeasonTemp
            ) = getCultivationFactorGauge(bs);

            // Write data to CSV
            string memory line = string.concat(
                "step2_user1_oscillation,",
                vm.toString(bs.season()),
                ",",
                vm.toString(prevSeasonTemp),
                ",",
                vm.toString(cultivationFactor)
            );
            vm.writeLine(csvPath, line);

            console.log("cultivationFactor", cultivationFactor);
            console.log("cultivationTemp", cultivationTemp);
            console.log("prevSeasonTemp", prevSeasonTemp);
            console.log("soil", bs.totalSoil());
            console.log("-------------------");
        }

        ////////////////// STEP 3: USER2 ORDER MAKES CULTIVATION FACTOR DECREASE TO MATCH NEW CAPACITY AT LOWER TEMP //////////////////

        // At 739% temperature, a user comes in and places a limit order to sow at 737,5% but not the full soil.

        // call sunrise
        // sow some soil to init: soil sown last season
        sowAmount(farmer2, 100e6);
        uint256 soilSownLastSeason = 100e6;
        stepSeason();

        // 3 seasons of some soil sown, temp decreasing, cultivation factor decreasing until the 2nd users capacity is met
        console.log("--------------------------------");
        console.log(
            "3 seasons of some soil sown, temp decreasing, cultivation factor decreasing until 2nd user's capacity is met"
        );
        console.log(
            "When the capacity is met, the new cultivation temperature is found and cultivation factor increases"
        );
        console.log("--------------------------------");
        for (uint256 i = 0; i < 3; i++) {
            // sow some soil, to make demand increasing and lower temp
            soilSownLastSeason = sowIncreasing(farmer2, soilSownLastSeason);

            // call sunrise
            stepSeason();

            // log season number and temperature
            console.log("Iteration", i + 1);
            console.log("season", bs.season());
            console.log("temperature", bs.weather().temp);

            // get cultivation factor gauge
            (
                uint256 cultivationFactor,
                uint256 cultivationTemp,
                uint256 prevSeasonTemp
            ) = getCultivationFactorGauge(bs);

            // Write data to CSV
            string memory line = string.concat(
                "step3_user2_some_sow_at_lower_temp,",
                vm.toString(bs.season()),
                ",",
                vm.toString(prevSeasonTemp),
                ",",
                vm.toString(cultivationFactor)
            );
            vm.writeLine(csvPath, line);

            console.log("cultivationFactor", cultivationFactor);
            console.log("cultivationTemp", cultivationTemp);
            console.log("prevSeasonTemp", prevSeasonTemp);
            console.log("soil", bs.totalSoil());
            console.log("-------------------");
        }

        ////////////////// STEP 4: OSCILLATION WITH USER2 ONLY //////////////////

        // User2 alternates between:
        // - Selling out all soil
        // - No sowing for 2 seasons until his 737% limit order is met
        console.log("--------------------------------");
        console.log("Oscillating pattern with User2 alternating between selling out and no sowing");
        console.log("--------------------------------");

        for (uint256 i = 0; i < 3; i++) {
            stepSeason();

            // log season number and temperature
            console.log("Iteration", i * 3 + 1);
            console.log("season", bs.season());
            console.log("temperature", bs.weather().temp);

            // get cultivation factor gauge
            (
                uint256 cultivationFactor,
                uint256 cultivationTemp,
                uint256 prevSeasonTemp
            ) = getCultivationFactorGauge(bs);

            // Write data to CSV
            string memory line = string.concat(
                "step4_user2_oscillation,",
                vm.toString(bs.season()),
                ",",
                vm.toString(prevSeasonTemp),
                ",",
                vm.toString(cultivationFactor)
            );
            vm.writeLine(csvPath, line);

            console.log("cultivationFactor", cultivationFactor);
            console.log("cultivationTemp", cultivationTemp);
            console.log("prevSeasonTemp", prevSeasonTemp);
            console.log("soil", bs.totalSoil());
            console.log("-------------------");

            // User2 sells out all soil
            console.log("User2 sells out all soil");
            sowAll(farmer2);

            // Two seasons of no sowing
            console.log("Two seasons of no sowing");
            for (uint256 j = 0; j < 2; j++) {
                stepSeason();

                // log season number and temperature
                console.log("Iteration", i * 3 + j + 2);
                console.log("season", bs.season());
                console.log("temperature", bs.weather().temp);

                // get cultivation factor gauge
                (cultivationFactor, cultivationTemp, prevSeasonTemp) = getCultivationFactorGauge(
                    bs
                );

                // Write data to CSV
                line = string.concat(
                    "step4_user2_oscillation,",
                    vm.toString(bs.season()),
                    ",",
                    vm.toString(prevSeasonTemp),
                    ",",
                    vm.toString(cultivationFactor)
                );
                vm.writeLine(csvPath, line);

                console.log("cultivationFactor", cultivationFactor);
                console.log("cultivationTemp", cultivationTemp);
                console.log("prevSeasonTemp", prevSeasonTemp);
                console.log("soil", bs.totalSoil());
                console.log("-------------------");
            }
        }
    }

    /////////////////// HELPER FUNCTIONS ///////////////////

    function sowAll(address farmer) public {
        // get available soil
        uint256 soil = bs.totalSoil();
        // mint pinto to farmer
        deal(L2_PINTO, farmer, soil);
        // sow
        vm.startPrank(farmer);
        // approve pinto
        IERC20(L2_PINTO).approve(address(bs), soil);
        // sow
        bs.sow(soil, 0, uint8(LibTransfer.From.EXTERNAL));
        vm.stopPrank();
    }

    function sowIncreasing(address farmer, uint256 soilSownLastSeason) public returns (uint256) {
        // get available soil
        // 5% increase to make demand increasing and lower temp
        uint256 totalSoil = bs.totalSoil();
        uint256 soilToSow = soilSownLastSeason + ((soilSownLastSeason * 5.1e6) / 100e6); // 5.1% increase
        if (soilToSow > totalSoil) {
            soilToSow = totalSoil;
        }
        // mint pinto to farmer
        deal(L2_PINTO, farmer, soilToSow);
        // sow
        vm.startPrank(farmer);
        // approve pinto
        IERC20(L2_PINTO).approve(address(bs), soilToSow);
        // sow
        console.log("sowing soil: ", soilToSow);
        bs.sow(soilToSow, 0, uint8(LibTransfer.From.EXTERNAL));
        vm.stopPrank();

        return soilToSow;
    }

    function sowAmount(address farmer, uint256 amount) public {
        // mint pinto to farmer
        deal(L2_PINTO, farmer, amount);
        // sow
        vm.startPrank(farmer);
        // approve pinto
        IERC20(L2_PINTO).approve(address(bs), amount);
        // sow
        bs.sow(amount, 0, uint8(LibTransfer.From.EXTERNAL));
        vm.stopPrank();
    }

    function stepSeason() public {
        // go forward 60 minutes
        vm.warp(block.timestamp + 61 minutes);
        vm.roll(block.number + 1);
        // call sunrise
        bs.sunrise();
        // updateAllChainlinkOraclesWithPreviousData();
    }

    function getCultivationFactorGauge(
        IMockFBeanstalk bs
    )
        internal
        view
        returns (uint256 cultivationFactor, uint256 cultivationTemp, uint256 prevSeasonTemp)
    {
        bytes memory cultivationFactorData = bs.getGaugeData(GaugeId.CULTIVATION_FACTOR);
        bytes memory cultivationFactorValue = bs.getGaugeValue(GaugeId.CULTIVATION_FACTOR);

        cultivationFactor = abi.decode(cultivationFactorValue, (uint256));

        (
            ,
            ,
            ,
            ,
            cultivationTemp, // temperature when soil was selling out and demand for soil was not decreasing.
            prevSeasonTemp // temperature of the previous season.
        ) = abi.decode(
            cultivationFactorData,
            (uint256, uint256, uint256, uint256, uint256, uint256)
        );
    }
}
