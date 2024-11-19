/*
 SPDX-License-Identifier: MIT
*/
pragma solidity ^0.8.20;

import "contracts/C.sol";
import "contracts/libraries/Token/LibTransfer.sol";
import "contracts/beanstalk/facets/sun/SeasonFacet.sol";
import "contracts/beanstalk/facets/sun/abstract/Sun.sol";
import {LibTransfer} from "contracts/libraries/Token/LibTransfer.sol";
import {LibBalance} from "contracts/libraries/Token/LibBalance.sol";
import {ShipmentRecipient} from "contracts/beanstalk/storage/System.sol";
import {LibShipping} from "contracts/libraries/LibShipping.sol";
import {LibReceiving} from "contracts/libraries/LibReceiving.sol";

/**
 * @title MockAdminFacet provides various mock functionality
 **/

contract MockAdminFacet is Sun {
    function mintBeans(address to, uint256 amount) external {
        BeanstalkERC20(s.sys.bean).mint(to, amount);
    }

    function ripen(uint256 amount) external {
        BeanstalkERC20(s.sys.bean).mint(address(this), amount);
        LibReceiving.receiveShipment(ShipmentRecipient.FIELD, amount, abi.encode(uint256(0)));
    }

    function rewardSilo(uint256 amount) external {
        BeanstalkERC20(s.sys.bean).mint(address(this), amount);
        LibReceiving.receiveShipment(ShipmentRecipient.SILO, amount, bytes(""));
    }

    function forceSunrise() external {
        updateStart();
        SeasonFacet sf = SeasonFacet(address(this));
        sf.sunrise();
    }

    function rewardSunrise(uint256 amount) public {
        updateStart();
        s.sys.season.current += 1;
        BeanstalkERC20(s.sys.bean).mint(address(this), amount);
        LibShipping.ship(amount);
    }

    function updateStart() private {
        SeasonFacet sf = SeasonFacet(address(this));
        int256 sa = int256(uint256(s.sys.season.current - sf.seasonTime()));
        if (sa >= 0) s.sys.season.start -= 3600 * (uint256(sa) + 1);
    }

    function updateStems() public {
        address[] memory siloTokens = LibWhitelistedTokens.getSiloTokens();
        for (uint256 i = 0; i < siloTokens.length; i++) {
            s.sys.silo.assetSettings[siloTokens[i]].milestoneStem = int96(
                s.sys.silo.assetSettings[siloTokens[i]].milestoneStem * 1e6
            );
        }
    }
}
