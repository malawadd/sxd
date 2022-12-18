// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./SXDTemplate.sol";

import "./oracles/TestOracle.sol";

contract SXD is SXDTemplate, TestOracle {
    uint256 private constant NUM_UNISWAP_PAIRS = 1;

    constructor(uint256 p) SXDTemplate() TestOracle(p) {}
}
