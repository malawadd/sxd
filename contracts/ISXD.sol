// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface ISXD {
    function mint(address to, uint256 minXdcOut)
        external
        payable
        returns (uint256);

    function burn(
        address from,
        address payable to,
        uint256 xdcToBurn,
        uint256 minXdcOut
    ) external returns (uint256);

    function fund(address to, uint256 minFxdOut)
        external
        payable
        returns (uint256);

    function defund(
        address from,
        address payable to,
        uint256 fxdToBurn,
        uint256 minXdcOut
    ) external returns (uint256);

    function defundFromFXD(
        address from,
        address payable to,
        uint256 fxdToBurn,
        uint256 minXdcOut
    ) external returns (uint256);
}
