// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

contract MockAnchoredView {
    uint256 internal _price;

    function set(uint256 value) external {
        _price = value;
    }

    function price(string calldata) external view returns (uint256) {
        return _price;
    }
}
