// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMultiFlowPump} from "contracts/interfaces/basin/IMultiFlowPump.sol";
import {Call, IWell} from "contracts/interfaces/basin/IWell.sol";
import {IBeanstalk} from "contracts/interfaces/IBeanstalk.sol";
import {IWellFunction} from "contracts/interfaces/basin/IWellFunction.sol";
import {ISiloedPinto} from "contracts/interfaces/ISiloedPinto.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {console} from "forge-std/console.sol";

/**
 * @title PriceManipulation
 * @author Beanstalk Farms
 * @notice Contract for checking Well deltaP values
 */
contract PriceManipulation {
    uint256 internal constant PRICE_PRECISION = 1e6;
    uint256 internal constant ONE_PINTO = 1e6;
    uint256 internal constant SLIPPAGE_PRECISION = 1e18;

    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant S_PINTO = 0x00b174d66adA7d63789087F50A9b9e0e48446dc1;

    IBeanstalk public immutable protocol;

    constructor(address protocolAddress) {
        protocol = IBeanstalk(protocolAddress);
    }

    /**
     * @notice Query the well to get current and instant asset prices denominated in Pinto. Ensure
     * that the current price is within the % slippage of the instant price.
     * This price is susceptible to manipulation and this is why an additional check to
     * see if the wells instantaneous and current deltaPs are within a 1% margin is implemented.
     * @param well The well to check the prices of.
     * @param token The token to check the prices of. Must be the token paired with Pinto in the well.
     * @param slippageRatio The % slippage of the instant price. 18 decimal precision.
     * @return valid Whether the price is valid and within slippage bounds.
     */
    function isValidSlippage(
        IWell well,
        IERC20 token,
        uint256 slippageRatio
    ) external returns (bool) {
        Call memory pump = well.pumps()[0];
        Call memory wellFunction = IWell(well).wellFunction();

        (, uint256 nonBeanIndex) = protocol.getNonBeanTokenAndIndexFromWell(address(well));
        uint256 beanIndex = nonBeanIndex == 0 ? 1 : 0;

        // Call sync on well to update pump data and avoid stale reserves.
        well.sync(address(this), 0);

        // Capped reserves are the current reserves capped with the data from the pump.
        uint256[] memory currentReserves = IWell(well).getReserves();

        uint256 currentPintoPerAsset = calculateTokenBeanPriceFromReserves(
            address(token),
            beanIndex,
            nonBeanIndex,
            currentReserves,
            wellFunction
        );
        if (currentPintoPerAsset == 0) return false;

        // InstantaneousReserves are exponential moving average (EMA).
        uint256[] memory instantReserves = IMultiFlowPump(pump.target).readInstantaneousReserves(
            address(well),
            pump.data
        );
        uint256 instantPintoPerAsset = calculateTokenBeanPriceFromReserves(
            address(token),
            beanIndex,
            nonBeanIndex,
            instantReserves,
            wellFunction
        );
        if (instantPintoPerAsset == 0) return false;

        // Current rate must be within slippage bounds relative to instantaneous rate.
        uint256 lowerLimit = instantPintoPerAsset -
            (slippageRatio * instantPintoPerAsset) /
            SLIPPAGE_PRECISION;
        uint256 upperLimit = instantPintoPerAsset +
            (slippageRatio * instantPintoPerAsset) /
            SLIPPAGE_PRECISION;
        if (currentPintoPerAsset < lowerLimit || currentPintoPerAsset > upperLimit) {
            return false;
        }
        return true;
    }

    /**
     * @notice Calculates the token price in terms of Bean by increasing
     * the bean reserves of the given well by 1 and recalculating the new reserves,
     * while maintaining the same liquidity levels.
     * This essentially simulates a swap of 1 Bean for the non bean token and quotes the price.
     * @dev wrapped in a try/catch to return gracefully. 6 decimal precision.
     * @dev Copied from Pinto Protocol internal library function.
     * @return price The price of the token in terms of Pinto.
     */
    function calculateTokenBeanPriceFromReserves(
        address nonBeanToken,
        uint256 beanIndex,
        uint256 nonBeanIndex,
        uint256[] memory reserves,
        Call memory wellFunction
    ) internal view returns (uint256 price) {
        // attempt to calculate the LP token Supply.
        try
            IWellFunction(wellFunction.target).calcLpTokenSupply(reserves, wellFunction.data)
        returns (uint256 lpTokenSupply) {
            uint256 oldReserve = reserves[nonBeanIndex];
            reserves[beanIndex] = reserves[beanIndex] + 1e6; // 1e6 == 1 Pinto.

            try
                IWellFunction(wellFunction.target).calcReserve(
                    reserves,
                    nonBeanIndex,
                    lpTokenSupply,
                    wellFunction.data
                )
            returns (uint256 newReserve) {
                // Measure the delta of the non bean reserve.
                // Due to the invariant of the well function, old reserve > new reserve.
                uint256 delta = oldReserve - newReserve;
                price = (10 ** (IERC20Metadata(nonBeanToken).decimals() + 6)) / delta;
            } catch {
                return 0;
            }
        } catch {
            return 0;
        }
    }

    // NOTE - do not use beanstalk pricing functions and logic. literally not worth the complexity
    //        for a simple set of chainlink calls.
    // need to come at this fresh
    // for each whitelisted asset,
    //   1. get the token/pinto price (wth is it this direction idk)
    //   2. get the token/usd price direct from chainlink (use millions if token has <= 8 decimals)
    //   3. calculate the pinto/usd price
    //   -  assume 1 usd = 1 usdc
    //   4. calculate the liquidity of the pools and scale all prices
    //   5. average all scaled prices
    //   6. scale by the sPinto redemption rate
    //   7. return sPinto / usdc with proper decimals

    /**
     * @notice Aggregate the instant price of a token from all whitelisted wells.
     */
    function aggregateInstantPrice() public view returns (uint256 usdcPerSPinto) {
        console.log("aggregating instant price...");
        address[] memory wells = protocol.getWhitelistedWellLpTokens();
        console.log("wells ", wells.length);

        uint256[] memory pintoPerUsdc = new uint256[](wells.length);

        // Total USD value of the well.
        uint256[] memory liquidity = new uint256[](wells.length);
        uint256 totalLiquidity;

        uint256 usdcPerUsd = protocol.getUsdTokenPrice(USDC);
        require(usdcPerUsd > 0, "Failed to fetch USDC price");
        console.log("usdcPerUsd", usdcPerUsd);

        // Go through each well and collect data.
        for (uint256 i; i < wells.length; i++) {
            IWell well = IWell(wells[i]);
            Call memory pump = well.pumps()[0];
            (address token, uint256 nonBeanIndex) = protocol.getNonBeanTokenAndIndexFromWell(
                address(well)
            );
            uint256 beanIndex = nonBeanIndex == 0 ? 1 : 0;

            // // Call sync on well to update pump data and avoid stale reserves.
            // well.sync(address(this), 0);

            // Instant reserves are the EMA reserves.
            uint256[] memory instantReserves = IMultiFlowPump(pump.target)
                .readInstantaneousReserves(address(well), pump.data);
            console.log("instantReserves[beanIndex]", instantReserves[beanIndex]);
            console.log("instantReserves[nonBeanIndex]", instantReserves[nonBeanIndex]);

            // Calculate the price of the token in terms of Pinto.
            uint256 pintoPerToken = calculateTokenBeanPriceFromReserves(
                token,
                beanIndex,
                nonBeanIndex,
                instantReserves,
                well.wellFunction()
            );
            console.log("pintoPerToken", pintoPerToken);
            if (pintoPerToken == 0) {
                continue;
            }

            uint256 pintoPerUsd;
            bool useMillions = IERC20Metadata(token).decimals() <= 8 ? true : false;
            if (!useMillions) {
                uint256 tokenPerUsd = protocol.getUsdTokenPrice(token); // 6 decimal
                console.log("tokenPerUsd", tokenPerUsd);
                if (tokenPerUsd == 0) {
                    continue;
                }
                pintoPerUsd = PRICE_PRECISION * pintoPerToken * tokenPerUsd;
                liquidity[i] =
                    instantReserves[beanIndex] /
                    pintoPerUsd +
                    instantReserves[nonBeanIndex] /
                    tokenPerUsd;
            } else {
                uint256 tokenPerMillionUsd = protocol.getMillionUsdPrice(token, 0); // 6 decimal
                console.log("tokenPerMillionUsd", tokenPerMillionUsd);
                if (tokenPerMillionUsd == 0) {
                    continue;
                }
                pintoPerUsd = (PRICE_PRECISION * pintoPerToken * tokenPerMillionUsd) / 1e6;
                liquidity[i] =
                    instantReserves[beanIndex] /
                    pintoPerUsd +
                    (instantReserves[nonBeanIndex] * 1e6) /
                    tokenPerMillionUsd;
            }
            console.log("pintoPerUsd", pintoPerUsd);

            totalLiquidity += liquidity[i];

            pintoPerUsdc[i] = pintoPerUsd / usdcPerUsd;
        }

        require(totalLiquidity > 0, "failed to retrieve reserves");

        uint256 aggregatePintoPerUsdc;
        for (uint256 i; i < wells.length; i++) {
            if (liquidity[i] == 0) continue;
            aggregatePintoPerUsdc += (pintoPerUsdc[i] * liquidity[i]) / totalLiquidity;
        }
        aggregatePintoPerUsdc = aggregatePintoPerUsdc / wells.length;

        uint256 pintoPerSPinto = ISiloedPinto(S_PINTO).previewRedeem(1e18);

        usdcPerSPinto = pintoPerSPinto * aggregatePintoPerUsdc;
    }
}
