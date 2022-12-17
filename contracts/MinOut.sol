// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

library MinOut {
    function parseMinTokenOut(uint256 xdcIn)
        internal
        pure
        returns (uint256 minTokenOut)
    {
        uint256 minPrice = xdcIn % 100000000000;
        if (minPrice != 0 && minPrice < 10000000) {
            minTokenOut = (xdcIn * minPrice) / 100;
        }
    }

    function parseMinXdcOut(uint256 tokenIn)
        internal
        pure
        returns (uint256 minXdcOut)
    {
        uint256 maxPrice = tokenIn % 100000000000;
        if (maxPrice != 0 && maxPrice < 10000000) {
            minXdcOut = (tokenIn * 100) / maxPrice;
        }
    }
}
