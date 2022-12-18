// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./Oracle.sol";

abstract contract SettableOracle is Oracle {
    function setPrice(uint256 price) public virtual;
}
