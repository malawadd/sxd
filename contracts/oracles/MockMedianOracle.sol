// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./SettableOracle.sol";
import "../ISXD.sol";

/**
 * @title MockMedianOracl
 */
contract MockMedianOracle is ISXD, SettableOracle {
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
        ISXD(
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
        override(Oracle, USM)
        returns (uint256 price)
    {
        price = (savedPrice != 0) ? savedPrice : super.cacheLatestPrice();
    }

    function latestPrice() public view override returns (uint256 price) {
        price = (savedPrice != 0) ? savedPrice : super.latestPrice();
    }
}
