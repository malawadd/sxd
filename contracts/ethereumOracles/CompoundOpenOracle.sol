// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../oracles/Oracle.sol";

interface UniswapAnchoredView {
    function price(string calldata symbol) external view returns (uint256);
}

/**
 * @title CompoundOpenOracle
 */
contract CompoundOpenOracle is Oracle {
    using SafeMath for uint256;

    uint256 private constant SCALE_FACTOR = 10**12; // Since Compound has 6 dec places, and latestPrice() needs 18

    UniswapAnchoredView private anchoredView;

    constructor(UniswapAnchoredView anchoredView_) public {
        anchoredView = anchoredView_;
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
        price = latestCompoundPrice();
    }

    function latestCompoundPrice() public view returns (uint256 price) {
        price = anchoredView.price("ETH").mul(SCALE_FACTOR);
    }
}
