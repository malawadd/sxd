// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

contract MockPair {
    uint112 internal _reserves0;
    uint112 internal _reserves1;
    uint32 _blockTimestamp;
    uint256 internal _price0CumulativeLast;
    uint256 internal _price1CumulativeLast;

    function setReserves(
        uint112 reserves0,
        uint112 reserves1,
        uint32 blockTimestamp
    ) external {
        _reserves0 = reserves0;
        _reserves1 = reserves1;
        _blockTimestamp = blockTimestamp;
    }

    function getReserves()
        external
        view
        returns (
            uint112,
            uint112,
            uint32
        )
    {
        return (_reserves0, _reserves1, _blockTimestamp);
    }

    function setCumulativePrices(uint256 cumPrice0, uint256 cumPrice1)
        external
    {
        _price0CumulativeLast = cumPrice0;
        _price1CumulativeLast = cumPrice1;
    }

    function price0CumulativeLast() external view returns (uint256) {
        return _price0CumulativeLast;
    }

    function price1CumulativeLast() external view returns (uint256) {
        return _price1CumulativeLast;
    }
}
