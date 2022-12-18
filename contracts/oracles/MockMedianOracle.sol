// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./MockAggregator.sol";
import "./MockAnchoredView.sol";
import "./MockPair.sol";

contract MedianOracle is MockAggregatorV3, MockAnchoredView, MockPair {
    using SafeMath for uint256;

    uint256 private constant NUM_UNISWAP_PAIRS = 1;

    constructor() {}

    function latestPrice() public view virtual returns (uint256 price) {}

    function cacheLatestPrice() public virtual returns (uint256 price) {}

    /**
     * @notice Currently only supports three inputs
     * @return median value
     */
    function median(
        uint256 a,
        uint256 b,
        uint256 c
    ) private pure returns (uint256) {
        bool ab = a > b;
        bool bc = b > c;
        bool ca = c > a;

        return (ca == ab ? a : (ab == bc ? b : c));
    }
}
