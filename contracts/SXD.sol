// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./SXDTemplate.sol";
import "./ethereumOracles/MedianOracle.sol";

contract SXD is SXDTemplate, MedianOracle {
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
        SXDTemplate()
        MedianOracle(
            chainlinkAggregator,
            compoundView,
            uniswapPair,
            uniswapToken0Decimals,
            uniswapToken1Decimals,
            uniswapTokensInReverseOrder
        )
    {}

    function cacheLatestPrice()
        public
        virtual
        override(Oracle, MedianOracle)
        returns (uint256 price)
    {
        price = super.cacheLatestPrice();
    }
}
