// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import {TestHelper, LibTransfer, C} from "test/foundry/utils/TestHelper.sol";
import {MockPump} from "contracts/mocks/well/MockPump.sol";
import {IWell, IERC20, Call} from "contracts/interfaces/basin/IWell.sol";
import {LibWhitelistedTokens} from "contracts/libraries/Silo/LibWhitelistedTokens.sol";
import {LibWellMinting} from "contracts/libraries/Minting/LibWellMinting.sol";
import {ShipmentPlanner} from "contracts/ecosystem/ShipmentPlanner.sol";
import {LibPRBMathRoundable} from "contracts/libraries/Math/LibPRBMathRoundable.sol";
import {PRBMath} from "@prb/math/contracts/PRBMath.sol";
import "forge-std/console.sol";

/**
 * @notice Tests the functionality of the sun, the distrubution of beans and soil.
 */
contract SunTest is TestHelper {
    // Events
    event Soil(uint32 indexed season, uint256 soil);
    event Shipped(uint32 indexed season, uint256 shipmentAmount);

    uint256 constant SUPPLY_BUDGET_FLIP = 1_000_000_000e6;

    using PRBMath for uint256;
    using LibPRBMathRoundable for uint256;

    function setUp() public {
        initializeBeanstalkTestState(true, true);
    }

    /**
     * @notice tests bean issuance with only the silo.
     * @dev 100% of new bean signorage should be issued to the silo.
     */
    function test_sunOnlySilo(int256 deltaB, uint256 caseId, uint256 blocksToRoll) public {
        uint32 currentSeason = bs.season();
        uint256 initialBeanBalance = bean.balanceOf(BEANSTALK);
        uint256 initalPods = bs.totalUnharvestable(0);
        // cases can only range between 0 and 143.
        caseId = bound(caseId, 0, 143);
        // deltaB cannot exceed uint128 max.
        deltaB = bound(
            deltaB,
            -int256(uint256(type(uint128).max)),
            int256(uint256(type(uint128).max))
        );

        blocksToRoll = bound(blocksToRoll, 0, 30);
        vm.roll(blocksToRoll);

        // soil event check.
        uint256 soilIssued;
        if (deltaB > 0) {
            // note: no soil is issued as no debt exists.
        } else {
            soilIssued = uint256(-deltaB);
        }
        vm.expectEmit();
        emit Soil(currentSeason + 1, soilIssued);

        season.sunSunrise(deltaB, caseId);

        // if deltaB is positive,
        // 1) beans are minted equal to deltaB.
        // 2) soil is equal to the amount of soil
        // needed to equal the newly paid off pods (scaled up or down).
        // 3) no pods should be paid off.
        if (deltaB >= 0) {
            assertEq(bean.balanceOf(BEANSTALK), uint256(deltaB), "invalid bean minted +deltaB");
        }
        // if deltaB is negative, soil is issued equal to deltaB.
        // no beans should be minted.
        if (deltaB <= 0) {
            assertEq(
                initialBeanBalance - bean.balanceOf(BEANSTALK),
                0,
                "invalid bean minted -deltaB"
            );
        }

        // in both cases, soil should be issued,
        // and pods should remain 0.
        assertEq(bs.totalSoil(), soilIssued, "invalid soil issued");
        assertEq(bs.totalUnharvestable(0), 0, "invalid pods");
    }

    /**
     * @notice tests bean issuance with a field and silo.
     * @dev bean mints are split between the field and silo 50/50.
     * In the case that the field is paid off with the new bean issuance,
     * the remaining bean issuance is given to the silo.
     */
    function test_sunFieldAndSilo(uint256 podsInField, int256 deltaB, uint256 caseId) public {
        // Set up shipment routes to include only Silo and one Field.
        setRoutes_siloAndFields();

        uint32 currentSeason = bs.season();
        uint256 initialBeanBalance = bean.balanceOf(BEANSTALK);
        // cases can only range between 0 and 143.
        caseId = bound(caseId, 0, 143);
        // deltaB cannot exceed uint128 max.
        deltaB = bound(
            deltaB,
            -int256(uint256(type(uint128).max)),
            int256(uint256(type(uint128).max))
        );
        // increase pods in field.
        bs.incrementTotalPodsE(0, podsInField);

        // soil event check.
        uint256 soilIssuedAfterMorningAuction;
        uint256 soilIssuedRightNow;
        uint256 beansToField;
        uint256 beansToSilo;
        if (deltaB > 0) {
            (beansToField, beansToSilo) = calcBeansToFieldAndSilo(uint256(deltaB), podsInField);
            (soilIssuedAfterMorningAuction, soilIssuedRightNow) = getSoilIssuedAbovePeg(
                beansToField,
                caseId
            );
        } else {
            soilIssuedAfterMorningAuction = uint256(-deltaB);
            soilIssuedRightNow = uint256(-deltaB);
        }
        vm.expectEmit();
        emit Soil(currentSeason + 1, soilIssuedAfterMorningAuction);

        season.sunSunrise(deltaB, caseId);

        // if deltaB is positive,
        // 1) beans are minted equal to deltaB.
        // 2) soil is equal to the amount of soil
        // needed to equal the newly paid off pods (scaled up or down).
        // 3) totalunharvestable() should decrease by the amount issued to the field.
        if (deltaB >= 0) {
            assertEq(bean.balanceOf(BEANSTALK), uint256(deltaB), "invalid bean minted +deltaB");
            assertEq(bs.totalSoil(), soilIssuedRightNow, "invalid soil @ +deltaB");
            assertEq(
                bs.totalUnharvestable(0),
                podsInField - beansToField,
                "invalid pods @ +deltaB"
            );
        }
        // if deltaB is negative, soil is issued equal to deltaB.
        // no beans should be minted.
        if (deltaB <= 0) {
            assertEq(
                initialBeanBalance - bean.balanceOf(BEANSTALK),
                0,
                "invalid bean minted -deltaB"
            );
            assertEq(bs.totalSoil(), soilIssuedRightNow, "invalid soil @ -deltaB");
            assertEq(bs.totalUnharvestable(0), podsInField, "invalid pods @ -deltaB");
        }
    }

    // TODO: This test will be broken, need to update Shipment Planner.
    // TODO: Improve this tests by handling multiple concurrent seasons with shipment edge cases.
    /**
     * @notice tests bean issuance with two fields, and a silo.
     * @dev bean mints are split between the field 0, field 1, silo.
     *      Points corresponding to the routes are 10, 45, 45.
     */
    function test_multipleSunrisesWithTwoFieldsAndSilo(
        uint256 podsInField0,
        uint256 podsInField1,
        int256[] memory deltaBList,
        uint256[] memory caseIdList
    ) public {
        vm.assume(deltaBList.length > 0);
        vm.assume(caseIdList.length > 0);
        uint256 numOfSeasons = deltaBList.length < caseIdList.length
            ? deltaBList.length
            : caseIdList.length;

        // test is capped to CP2 constraints. See {ConstantProduct2.sol}

        // increase pods in field.
        bs.incrementTotalPodsE(0, podsInField0);
        bs.incrementTotalPodsE(1, podsInField1);

        // Set up second Field. Update Routes and Plan getters.
        vm.prank(deployer);
        bs.addField();
        vm.prank(deployer);
        bs.setActiveField(1, 1);
        setRoutes_siloAndTwoFields();

        for (uint256 i; i < numOfSeasons; i++) {
            // int256 deltaB = deltaBList[i];
            // uint256 caseId = caseIdList[i];

            // deltaB cannot exceed uint128 max. Bound tighter here to handle repeated seasons.
            int256 deltaB = bound(deltaBList[i], type(int96).min, type(int96).max);
            // cases can only range between 0 and 143.
            uint256 caseId = bound(caseIdList[i], 0, 143);

            // May change at each sunrise.
            uint256 priorEarnedBeans = bs.totalEarnedBeans();
            uint256 priorBeansInBeanstalk = bean.balanceOf(BEANSTALK);

            vm.roll(block.number + 300);

            // vm.expectEmit(false, false, false, false);
            // emit Soil(0, 0);

            season.sunSunrise(deltaB, caseId);

            // if deltaB is positive,
            // 1) beans are minted equal to deltaB.
            // 2) soil is equal to the amount of soil
            // needed to equal the newly paid off pods (scaled up or down).
            // 3) totalunharvestable() should decrease by the amount issued to the field.
            if (deltaB >= 0) {
                assertEq(
                    bean.balanceOf(BEANSTALK) - priorBeansInBeanstalk,
                    uint256(deltaB),
                    "invalid bean minted +deltaB"
                );

                // Verify amount of change in Field 0. Either a max of cap or a min of 5/11 mints.
                {
                    uint256 beansToField0 = podsInField0 - bs.totalUnharvestable(0);
                    // There is no case where a Field receives more than 50% of mints (shared w/ Silo).
                    assertLe(beansToField0, uint256(deltaB) / 2, "too many Beans to Field 0");
                    // Field should either receive its exact cap, or a minimum of its point ratio.
                    if (beansToField0 != podsInField0) {
                        assertGe(
                            beansToField0,
                            (uint256(deltaB) * 1) / 11,
                            "not enough Beans to Field 0"
                        );
                    }
                    podsInField0 -= beansToField0;
                }

                // Verify amount of change in Field 1. Either a max of cap or a min of 1/11 mints.
                {
                    uint256 beansToField1 = podsInField1 - bs.totalUnharvestable(1);
                    // There is no case where a Field receives more than 50% of mints (shared w/ Silo).
                    assertLe(beansToField1, uint256(deltaB) / 2, "too many Beans to Field 1");
                    // Field should either receive its exact cap, or a minimum of its point ratio.
                    if (beansToField1 != podsInField1) {
                        assertGe(
                            beansToField1,
                            (uint256(deltaB) * 5) / 11,
                            "not enough Beans to Field 1"
                        );
                    }
                    podsInField1 -= beansToField1;

                    // Verify soil amount. Field 1 is the active Field.
                    (
                        uint256 soilIssuedAfterMorningAuction,
                        uint256 soilIssuedRightNow
                    ) = getSoilIssuedAbovePeg(beansToField1, caseId);
                    assertEq(bs.totalSoil(), soilIssuedRightNow, "invalid soil @ +deltaB");
                }

                // Verify amount of change in Silo. Min of 5/11 mints.
                {
                    uint256 beansToSilo = bs.totalEarnedBeans() - priorEarnedBeans;
                    // Silo can receive at most 100% of deltaB.
                    assertLe(beansToSilo, uint256(deltaB), "too many Beans to Silo");
                    // Silo should receive at least 5/11 of deltaB.
                    assertGe(beansToSilo, (uint256(deltaB) * 5) / 11, "not enough Beans to Silo");
                }
            }
            // if deltaB is negative, soil is issued equal to deltaB.
            // no beans should be minted.
            if (deltaB <= 0) {
                assertEq(
                    bean.balanceOf(BEANSTALK) - priorBeansInBeanstalk,
                    0,
                    "invalid bean minted -deltaB"
                );
                assertEq(bs.totalUnharvestable(0), podsInField0, "invalid field 0 pods @ -deltaB");
                assertEq(bs.totalUnharvestable(1), podsInField1, "invalid field 1 pods @ -deltaB");
                uint256 soilIssued = uint256(-deltaB);
                vm.roll(block.number + 50);
                assertEq(bs.totalSoil(), soilIssued, "invalid soil @ -deltaB");
            }
        }
    }

    function test_multipleSunrisesWithTwoFieldsAndBudgetAndPayback(
        uint256 podsInField0,
        uint256 podsInField1,
        int256[] memory deltaBList,
        uint256[] memory caseIdList
    ) public {
        vm.assume(deltaBList.length > 0);
        vm.assume(caseIdList.length > 0);
        uint256 numOfSeasons = deltaBList.length < caseIdList.length
            ? deltaBList.length
            : caseIdList.length;

        // test is capped to CP2 constraints. See {ConstantProduct2.sol}

        uint256 beansInBudget;
        uint256 beansInPaybackContract;

        // increase pods in field.
        uint256 podsInField0 = bound(podsInField0, 0, type(uint64).max);
        uint256 podsInField1 = bound(podsInField1, 0, type(uint64).max);
        bs.incrementTotalPodsE(0, podsInField0);
        bs.incrementTotalPodsE(1, podsInField1);

        // Set up second Field. Update Routes and Plan getters.
        vm.prank(deployer);
        bs.addField();
        vm.prank(deployer);
        bs.setActiveField(0, 1);
        setRoutes_all();

        for (uint256 i; i < numOfSeasons; i++) {
            // deltaB cannot exceed uint128 max. Bound tighter here to handle repeated seasons.
            int256 deltaB = bound(deltaBList[i], -10_000_000e6, 10_000_000e6);
            // cases can only range between 0 and 143.
            uint256 caseId = bound(caseIdList[i], 0, 143);

            // May change at each sunrise.
            uint256 priorEarnedBean = bs.totalEarnedBeans();
            uint256 priorBeanInBeanstalk = bean.balanceOf(BEANSTALK);

            vm.roll(block.number + 300);

            season.sunSunrise(deltaB, caseId);

            // if deltaB is positive,
            // 1) bean are minted equal to deltaB.
            // 2) soil is equal to the amount of soil
            // needed to equal the newly paid off pods (scaled up or down).
            // 3) totalunharvestable() should decrease by the amount issued to the field.
            if (deltaB > 0) {
                assertGe(
                    bean.balanceOf(BEANSTALK) - priorBeanInBeanstalk,
                    (uint256(deltaB) * 2) / 100, // Payback contract Bean are sent externally.
                    "invalid bean minted +deltaB"
                );

                // Verify amount of change in Field 0. Either a max of cap or a min of 48.33/100 mints.
                {
                    uint256 beanToField0 = podsInField0 - bs.totalUnharvestable(0);
                    // There is no case where a Field receives more than 50% of mints (shared w/ Silo).
                    assertLe(beanToField0, uint256(deltaB) / 2, "too many Bean to Field 0");
                    // Field should either receive its exact cap, or a minimum of its point ratio.
                    if (beanToField0 != podsInField0) {
                        assertGe(
                            beanToField0,
                            (uint256(deltaB) * 48) / 100, // Rouding buffer
                            "not enough Bean to Field 0"
                        );
                    }
                    podsInField0 -= beanToField0;

                    // Verify soil amount. Field 0 is the active Field.
                    (
                        uint256 soilIssuedAfterMorningAuction,
                        uint256 soilIssuedRightNow
                    ) = getSoilIssuedAbovePeg(beanToField0, caseId);
                    assertEq(bs.totalSoil(), soilIssuedRightNow, "invalid soil @ +deltaB");
                }

                // Verify amount of change in Field 1.
                {
                    uint256 harvestablePodsField1 = podsInField1 - bs.totalUnharvestable(1);
                    if (bs.totalUnharvestable(1) > 0) {
                        // There is no case where a Field receives more than 50% of mints (shared w/ Silo).
                        assertLe(
                            harvestablePodsField1,
                            uint256(deltaB) / 2,
                            "too many Bean to Field 1"
                        );
                        if (inBudgetPhase()) {
                            assertEq(harvestablePodsField1, 0, "invalid bean minted to Field 1");
                        }
                        // If 100% in payback phase, min of 1/100 mints.
                        // Field should either receive its exact cap, or a minimum of its point ratio.
                        else if (inPaybackPhase(uint256(deltaB))) {
                            if (harvestablePodsField1 != podsInField1) {
                                assertGe(
                                    harvestablePodsField1,
                                    (uint256(deltaB) * 1) / 100,
                                    "not enough Bean to Field 1"
                                );
                            }
                        }
                    }
                    podsInField1 -= harvestablePodsField1;
                }

                // Verify amount of change in Budget internal balance.
                {
                    uint256 beanToBudget = bs.getInternalBalance(budget, address(bean)) -
                        beansInBudget;
                    // Budget can receive at most 50% of deltaB.
                    assertLe(beanToBudget, uint256(deltaB) / 2, "too many Bean to Budget");
                    // If fully in budget phase, min of 3/100 mints.
                    if (inBudgetPhase()) {
                        assertEq(
                            beanToBudget,
                            (uint256(deltaB) * 3) / 100,
                            "not enough Bean to Budget"
                        );
                    }
                    // If fully in payback phase, 0 mints.
                    else if (inPaybackPhase(uint256(deltaB))) {
                        assertEq(beanToBudget, 0, "invalid bean minted to Budget");
                    }

                    beansInBudget += beanToBudget;
                }
                // Verify amount of change in Payback external balance.
                {
                    uint256 beansToPaybackContract = bean.balanceOf(payback) -
                        beansInPaybackContract;

                    // Payback can receive at most 50% of deltaB.
                    assertLe(
                        beansToPaybackContract,
                        uint256(deltaB) / 2,
                        "too many Bean to payback contract"
                    );

                    // If 100% in payback phase, min of 1/100 mints.
                    // Field should either receive its exact cap, or a minimum of its point ratio.
                    if (inBudgetPhase()) {
                        assertEq(
                            beansToPaybackContract,
                            0,
                            "invalid bean minted to payback contract"
                        );
                    } else if (inPaybackPhase(uint256(deltaB))) {
                        assertGe(
                            beansToPaybackContract,
                            (uint256(deltaB) * 2) / 100,
                            "not enough Bean to payback contract in payback phase"
                        );
                    }

                    beansInPaybackContract += beansToPaybackContract;
                }

                // Verify amount of change in Silo. Min of 48.33/100 mints.
                {
                    uint256 beanToSilo = bs.totalEarnedBeans() - priorEarnedBean;
                    // Silo can receive at most 100% of deltaB.
                    assertLe(beanToSilo, uint256(deltaB), "too many Bean to Silo");
                    // Silo should receive at least 48.33/100 of deltaB.
                    assertGe(
                        beanToSilo,
                        (uint256(deltaB) * 48) / 100, // Rounding buffer
                        "not enough Bean to Silo"
                    );
                }
            }
            // if deltaB is negative, soil is issued equal to deltaB.
            // no bean should be minted.
            if (deltaB <= 0) {
                assertEq(
                    bean.balanceOf(BEANSTALK) - priorBeanInBeanstalk,
                    0,
                    "invalid bean minted -deltaB"
                );
                assertEq(bs.totalUnharvestable(0), podsInField0, "invalid field 0 pods @ -deltaB");
                assertEq(bs.totalUnharvestable(1), podsInField1, "invalid field 1 pods @ -deltaB");
                uint256 soilIssued = uint256(-deltaB);
                vm.roll(block.number + 50);
                assertEq(bs.totalSoil(), soilIssued, "invalid soil @ -deltaB");
            }
        }
    }

    function test_partials() public {
        uint256 beansInBudget;
        uint256 beansInPaybackContract;

        // increase pods in field.
        bs.incrementTotalPodsE(0, 100_000_000_000e6);
        bs.incrementTotalPodsE(1, 100_000_000_000e6);
        uint256 podsInField1 = bs.totalUnharvestable(1);

        // Set up second Field. Update Routes and Plan getters.
        vm.prank(deployer);
        bs.addField();
        vm.prank(deployer);
        bs.setActiveField(0, 1);
        setRoutes_all();

        uint256 deltaB = 50_000_000e6;
        uint256 caseId = 1;

        for (uint256 i; i < 19; i++) {
            vm.roll(block.number + 300);
            season.sunSunrise(int256(deltaB), caseId);
        }

        // Almost ready to cross supply threshold to switch from budget to payback.
        assertEq(inBudgetPhase(), true, "not in budget phase");
        assertEq(inPaybackPhase(0), false, "in payback phase");

        uint256 priorBeansInBudget = bs.getInternalBalance(budget, address(bean));
        uint256 priorBeansInPayback = bean.balanceOf(payback);
        uint256 priorHarvestablePodsPaybackField = podsInField1 - bs.totalUnharvestable(1);

        assertEq(
            priorBeansInBudget,
            (deltaB * 19 * 3) / 100,
            "invalid budget balance before partial"
        );
        assertEq(priorBeansInPayback, 0, "invalid payback balance before partial");

        deltaB = 80_000_000e6;
        vm.roll(block.number + 300);
        season.sunSunrise(int256(deltaB), caseId);

        // 3% of mint goes to budget and payback.
        // 5/8 of that goes to budget.
        assertEq(
            bs.getInternalBalance(budget, address(bean)),
            priorBeansInBudget + (deltaB * 3 * 5) / 100 / 8,
            "invalid budget balance from partial"
        );
        // 3/8 of that goes to payback, which is split 2/8 to payback contract and 1/8 to payback field.
        assertEq(
            bean.balanceOf(payback),
            priorBeansInPayback + ((deltaB * 3 * 2) / 100 / 8),
            "invalid payback contract balance from partial"
        );
        assertEq(
            podsInField1 - bs.totalUnharvestable(1),
            priorHarvestablePodsPaybackField + ((deltaB * 3 * 1) / 100 / 8),
            "invalid payback field balance from partial"
        );

        // 100% of the 3% goes to payback.
        priorBeansInBudget = bs.getInternalBalance(budget, address(bean));
        priorBeansInPayback = bean.balanceOf(payback);
        priorHarvestablePodsPaybackField = podsInField1 - bs.totalUnharvestable(1);
        deltaB = 1_000_000e6;
        vm.roll(block.number + 300);
        season.sunSunrise(int256(deltaB), caseId);
        assertEq(
            bs.getInternalBalance(budget, address(bean)),
            priorBeansInBudget,
            "invalid budget balance after partial"
        );
        assertEq(
            bean.balanceOf(payback),
            priorBeansInPayback + (deltaB * 2) / 100,
            "invalid payback contract balance after partial"
        );
        assertEq(
            podsInField1 - bs.totalUnharvestable(1),
            priorHarvestablePodsPaybackField + ((deltaB * 1) / 100),
            "invalid payback field balance after partial"
        );

        // Silo is paid off. Shift to 1.5% payback contract and 1.5% payback field.
        deal(address(bean), payback, 1_000_000_000e6 / 4, true);
        priorBeansInBudget = bs.getInternalBalance(budget, address(bean));
        priorBeansInPayback = bean.balanceOf(payback);
        priorHarvestablePodsPaybackField = podsInField1 - bs.totalUnharvestable(1);
        deltaB = 1_000e6;
        vm.roll(block.number + 300);
        season.sunSunrise(int256(deltaB), caseId);
        assertEq(
            bs.getInternalBalance(budget, address(bean)),
            priorBeansInBudget,
            "invalid budget balance after silo paid off"
        );
        assertEq(
            bean.balanceOf(payback),
            priorBeansInPayback + (deltaB * 15) / 1000,
            "invalid payback contract balance after silo paid off"
        );
        assertEq(
            podsInField1 - bs.totalUnharvestable(1),
            priorHarvestablePodsPaybackField + ((deltaB * 15) / 1000),
            "invalid payback field balance after silo paid off"
        );

        // Barn is paid off. Shift to 3% payback field. 0% to payback contract.
        deal(address(bean), payback, 1_000_000_000e6, true);
        priorBeansInBudget = bs.getInternalBalance(budget, address(bean));
        priorBeansInPayback = bean.balanceOf(payback);
        priorHarvestablePodsPaybackField = podsInField1 - bs.totalUnharvestable(1);
        deltaB = 1_000e6;
        vm.roll(block.number + 300);
        season.sunSunrise(int256(deltaB), caseId);
        assertEq(
            bs.getInternalBalance(budget, address(bean)),
            priorBeansInBudget,
            "invalid budget balance after barn is paid off"
        );
        assertEq(
            bean.balanceOf(payback),
            priorBeansInPayback,
            "invalid payback contract balance after barn is paid off"
        );
        assertEq(
            podsInField1 - bs.totalUnharvestable(1),
            priorHarvestablePodsPaybackField + ((deltaB * 3) / 100),
            "invalid payback field balance after barn is paid off"
        );
    }

    function test_soilBelowPeg() public {
        // set inst reserves (instDeltaB: -1999936754446796632414)
        setInstantaneousReserves(BEAN_WSTETH_WELL, 1000e18, 1000e18);
        setInstantaneousReserves(BEAN_ETH_WELL, 1000e18, 1000e18);
        int256 twaDeltaB = -1000;
        uint32 currentSeason = bs.season();
        vm.expectEmit();
        // expect the minimum of the -twaDeltaB and -instDeltaB to be used.
        emit Soil(currentSeason + 1, 1000);
        season.sunSunrise(twaDeltaB, 1);
        assertEq(bs.totalSoil(), 1000);
    }

    function test_soilBelowPegInstGtZero() public {
        // set inst reserves (instDeltaB: +415127766016)
        setInstantaneousReserves(BEAN_WSTETH_WELL, 10000e6, 10000000e18);
        setInstantaneousReserves(BEAN_ETH_WELL, 100000e6, 10000000e18);
        int256 twaDeltaB = -1000;
        uint32 currentSeason = bs.season();
        vm.expectEmit();
        // expect the twaDeltaB to be used.
        emit Soil(currentSeason + 1, 1000);
        season.sunSunrise(twaDeltaB, 1);
        assertEq(bs.totalSoil(), 1000);
    }

    ////// HELPER FUNCTIONS //////

    /**
     * @notice calculates the distrubution of field and silo beans.
     * @dev TODO: generalize field division.
     */
    function calcBeansToFieldAndSilo(
        uint256 beansIssued,
        uint256 podsInField
    ) internal returns (uint256 beansToField, uint256 beansToSilo) {
        beansToField = beansIssued / 2 > podsInField ? podsInField : beansIssued / 2;
        beansToSilo = beansIssued - beansToField;
    }

    /**
     * @notice calculates the amount of soil issued above peg.
     * @dev see {Sun.sol}.
     */
    function getSoilIssuedAbovePeg(
        uint256 podsRipened,
        uint256 caseId
    ) internal view returns (uint256 soilIssuedAfterMorningAuction, uint256 soilIssuedRightNow) {
        uint256 TEMPERATURE_PRECISION = 1e6;
        uint256 ONE_HUNDRED_TEMP = 100 * TEMPERATURE_PRECISION;

        soilIssuedAfterMorningAuction = (podsRipened * 100) / (100 + (bs.maxTemperature() / 1e6));

        if (caseId % 36 >= 27) {
            soilIssuedAfterMorningAuction = (soilIssuedAfterMorningAuction * 0.5e18) / 1e18; // high podrate
        } else if (caseId % 36 < 8) {
            soilIssuedAfterMorningAuction = (soilIssuedAfterMorningAuction * 1.5e18) / 1e18; // low podrate
        }

        soilIssuedRightNow = soilIssuedAfterMorningAuction.mulDiv(
            bs.maxTemperature() + ONE_HUNDRED_TEMP,
            bs.temperature() + ONE_HUNDRED_TEMP
        );
    }

    function setInstantaneousReserves(address well, uint256 reserve0, uint256 reserve1) public {
        Call[] memory pumps = IWell(well).pumps();
        for (uint256 i = 0; i < pumps.length; i++) {
            address pump = pumps[i].target;
            // pass to the pump the reserves that we actually have in the well
            uint256[] memory reserves = new uint256[](2);
            reserves[0] = reserve0;
            reserves[1] = reserve1;
            MockPump(pump).setInstantaneousReserves(well, reserves);
        }
    }

    function inBudgetPhase() internal view returns (bool) {
        return bean.totalSupply() <= SUPPLY_BUDGET_FLIP;
    }

    function inPaybackPhase(uint256 deltaB) internal view returns (bool) {
        uint256 minted = bs.time().standardMintedBeans;
        return bean.totalSupply() > SUPPLY_BUDGET_FLIP + minted;
    }
}
