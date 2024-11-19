// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {AppStorage} from "contracts/beanstalk/storage/AppStorage.sol";
import {LibDiamond} from "contracts/libraries/LibDiamond.sol";

contract OwnershipFacet {
    AppStorage internal s;

    function transferOwnership(address _newOwner) external {
        LibDiamond.enforceIsContractOwner();
        s.sys.ownerCandidate = _newOwner;
    }

    function claimOwnership() external {
        require(s.sys.ownerCandidate == msg.sender, "Ownership: Not candidate");
        LibDiamond.setContractOwner(msg.sender);
        delete s.sys.ownerCandidate;
    }

    function owner() external view returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    function ownerCandidate() external view returns (address ownerCandidate_) {
        ownerCandidate_ = s.sys.ownerCandidate;
    }
}
