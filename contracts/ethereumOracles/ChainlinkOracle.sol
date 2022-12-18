// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../oracles/Oracle.sol";

/**
 * @title ChainlinkOracle
 */
contract ChainlinkOracle is Oracle {
    using SafeMath for uint256;

    uint256 private constant SCALE_FACTOR = 10**10; // Since Chainlink has 8 dec places, and latestPrice() needs 18

    AggregatorV3Interface private aggregator;

    constructor(AggregatorV3Interface aggregator_) public {
        aggregator = aggregator_;
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     * @return price
     */
    function latestPrice()
        public
        view
        virtual
        override
        returns (uint256 price)
    {
        price = latestChainlinkPrice();
    }

    function latestChainlinkPrice() public view returns (uint256 price) {
        (, int256 rawPrice, , , ) = aggregator.latestRoundData();
        price = uint256(rawPrice).mul(SCALE_FACTOR); // TODO: Cast safely
    }
}
