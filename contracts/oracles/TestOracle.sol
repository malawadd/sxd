// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./SettableOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestOracle is SettableOracle, Ownable {
    uint256 internal savedPrice;

    constructor(uint256 p) public {
        setPrice(p);
    }

    function latestPrice() public view override returns (uint256) {
        return savedPrice;
    }

    function setPrice(uint256 p) public override {
        savedPrice = p;
    }
}
