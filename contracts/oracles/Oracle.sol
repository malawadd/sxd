// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

abstract contract Oracle {
    function latestPrice() public view virtual returns (uint256 price); // Prices must be WAD-scaled - 18 decimal places

    /**
     * @dev This pure virtual implementation, which is intended to be (optionally) overridden by stateful implementations,
     * confuses solhint into giving a "Function state mutability can be restricted to view" warning.
     */
    function cacheLatestPrice() public virtual returns (uint256 price) {
        price = latestPrice(); // Default implementation doesn't do any cacheing, just returns price.  But override as needed
    }
}
