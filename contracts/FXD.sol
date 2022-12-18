// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc20permit/contracts/ERC20Permit.sol";
import "./ISXD.sol";
import "./MinOut.sol";

/**
 * @title Fxd Token
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 *
 * @notice This should be owned by the stablecoin.
 */
contract FXD is ERC20Permit, Ownable {
    ISXD public immutable sxd;

    constructor(ISXD sxd_) ERC20Permit("Stable XDC", "SXD") {
        sxd = sxd_;
    }

    /**
     * @notice If anyone sends Xdc here, assume they intend it as a `fund`.
     * If decimals 8 to 11 (included) of the amount of Xdc received are `0000` then the next 7 will
     * be parsed as the minimum Xdc price accepted, with 2 digits before and 5 digits after the comma.
     */
    receive() external payable {
        sxd.fund{value: msg.value}(
            msg.sender,
            MinOut.parseMinTokenOut(msg.value)
        );
    }

    /**
     * @notice If a user sends Fxd tokens directly to this contract (or to the sxd contract), assume they intend it as a `defund`.
     * If using `transfer`/`transferFrom` as `defund`, and if decimals 8 to 11 (included) of the amount transferred received
     * are `0000` then the next 7 will be parsed as the maximum Fxd price accepted, with 5 digits before and 2 digits after the comma.
     */
    function transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        if (
            recipient == address(this) ||
            recipient == address(sxd) ||
            recipient == address(0)
        ) {
            sxd.defundFromFXD(
                sender,
                payable(sender),
                amount,
                MinOut.parseMinXdcOut(amount)
            );
        } else {
            super._transfer(sender, recipient, amount);
        }
    }

    /**
     * @notice Mint new Fxd to the _recipient
     *
     * @param _recipient address to mint to
     * @param _amount amount to mint
     */
    function mint(address _recipient, uint256 _amount) external onlyOwner {
        _mint(_recipient, _amount);
    }

    /**
     * @notice Burn Fxd from _holder
     *
     * @param _holder address to burn from
     * @param _amount amount to burn
     */
    function burn(address _holder, uint256 _amount) external onlyOwner {
        _burn(_holder, _amount);
    }
}
