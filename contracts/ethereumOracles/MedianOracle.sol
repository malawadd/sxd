// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./ChainlinkOracle.sol";
import "./CompoundOpenOracle.sol";
import "./UniswapV2TWAPOracle.sol";

contract MedianOracle is
    ChainlinkOracle,
    CompoundOpenOracle,
    OurUniswapV2TWAPOracle
{
    using SafeMath for uint256;

    uint256 private constant NUM_UNISWAP_PAIRS = 3;

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair,
        uint256 uniswapToken0Decimals,
        uint256 uniswapToken1Decimals,
        bool uniswapTokensInReverseOrder
    )
        public
        ChainlinkOracle(chainlinkAggregator)
        CompoundOpenOracle(compoundView)
        OurUniswapV2TWAPOracle(
            uniswapPair,
            uniswapToken0Decimals,
            uniswapToken1Decimals,
            uniswapTokensInReverseOrder
        )
    {}

    function latestPrice()
        public
        view
        override(ChainlinkOracle, CompoundOpenOracle, OurUniswapV2TWAPOracle)
        returns (uint256 price)
    {
        price = median(
            ChainlinkOracle.latestPrice(),
            CompoundOpenOracle.latestPrice(),
            OurUniswapV2TWAPOracle.latestPrice()
        );
    }

    function cacheLatestPrice()
        public
        virtual
        override(Oracle, OurUniswapV2TWAPOracle)
        returns (uint256 price)
    {
        price = median(
            ChainlinkOracle.latestPrice(), // Not ideal to call latestPrice() on two of these
            CompoundOpenOracle.latestPrice(), // and cacheLatestPrice() on one...  But works, and
            OurUniswapV2TWAPOracle.cacheLatestPrice()
        ); // inheriting them like this saves significant gas
    }

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
