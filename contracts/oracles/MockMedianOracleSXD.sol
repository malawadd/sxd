// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./SettableOracle.sol";
import "../SXD.sol";

/**
 * @title MockMedianOracleSXD
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice Like SXD (so, also inheriting MedianOracle), but allows latestPrice() to be set for testing purposes
 */
contract MockMedianOracleSXD is SXD, SettableOracle {
    uint256 private constant NUM_UNISWAP_PAIRS = 3;

    uint256 private savedPrice;

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair,
        uint256 uniswapToken0Decimals,
        uint256 uniswapToken1Decimals,
        bool uniswapTokensInReverseOrder
    )
        public
        SXD(
            chainlinkAggregator,
            compoundView,
            uniswapPair,
            uniswapToken0Decimals,
            uniswapToken1Decimals,
            uniswapTokensInReverseOrder
        )
    {}

    function setPrice(uint256 p) public override {
        savedPrice = p;
    }

    function cacheLatestPrice()
        public
        override(Oracle, SXD)
        returns (uint256 price)
    {
        price = (savedPrice != 0) ? savedPrice : super.cacheLatestPrice();
    }

    function latestPrice()
        public
        view
        override(MedianOracle, Oracle)
        returns (uint256 price)
    {
        price = (savedPrice != 0) ? savedPrice : super.latestPrice();
    }
}
