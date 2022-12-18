// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "erc20permit/contracts/ERC20Permit.sol";
import "./ISXD.sol";
import "./Delegable.sol";
import "./WadMath.sol";
import "./FXD.sol";
import "./MinOut.sol";
import "./oracles/Oracle.sol";

// import "@nomiclabs/buidler/console.sol";

/**
 * @title SXDTemplate
 *
 * This abstract SXD contract must be inherited by a concrete implementation, that also adds an Oracle implementation - eg, by
 * also inheriting a concrete Oracle implementation.  See SXD (and MockSXD) for an example.
 *
 * We use this inheritance-based design (rather than the more natural, and frankly normally more correct, composition-based design
 * of storing the Oracle here as a variable), because inheriting the Oracle makes all the latestPrice() calls *internal* rather
 * than calls to a separate oracle contract (or multiple contracts) - which leads to a significant saving in gas.
 */
abstract contract SXDTemplate is ISXD, Oracle, ERC20Permit, Delegable {
    using Address for address payable;
    using SafeMath for uint256;
    using WadMath for uint256;

    enum Side {
        Buy,
        Sell
    }

    event minFxdBuyPriceChanged(uint256 previous, uint256 latest);
    event BuySellAdjustmentChanged(uint256 previous, uint256 latest);

    uint256 public constant WAD = 10**18;
    uint256 public constant MAX_DEBT_RATIO = (WAD * 8) / 10; // 80%
    uint256 public constant MIN_FXD_BUY_PRICE_HALF_LIFE = 1 days; // Solidity for 1 * 24 * 60 * 60
    uint256 public constant BUY_SELL_ADJUSTMENT_HALF_LIFE = 1 minutes; // Solidity for 1 * 60

    FXD public immutable fxd;

    struct TimedValue {
        uint32 timestamp;
        uint224 value;
    }

    TimedValue public minFxdBuyPriceStored;
    TimedValue public buySellAdjustmentStored =
        TimedValue({timestamp: 0, value: uint224(WAD)});

    constructor() ERC20Permit("Stable XDC", "SXD") {
        fxd = new FXD(this);
    }

    /** EXTERNAL TRANSACTIONAL FUNCTIONS **/

    /**
     * @notice Mint new SXD, sending it to the given address, and only if the amount minted >= minSXDOut.  The amount of XDC is
     * passed in as msg.value.
     * @param to address to send the SXD to.
     * @param minSxdOut Minimum accepted SXD for a successful mint.
     */
    function mint(address to, uint256 minSxdOut)
        external
        payable
        override
        returns (uint256 sxdOut)
    {
        sxdOut = _mintSxd(to, minSxdOut);
    }

    /**
     * @dev Burn SXD in exchange for xdc.
     * @param from address to deduct the SXD from.
     * @param to address to send the xdc to.
     * @param sxdToBurn Amount of SXD to burn.
     * @param minXdcOut Minimum accepted xdc for a successful burn.
     */
    function burn(
        address from,
        address payable to,
        uint256 sxdToBurn,
        uint256 minXdcOut
    )
        external
        override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint256 xdcOut)
    {
        xdcOut = _burnSdx(from, to, sxdToBurn, minXdcOut);
    }

    /**
     * @notice Funds the pool with XDC, minting new FXD and sending it to the given address, but only if the amount minted >=
     * minFxdOut.  The amount of XDC is passed in as msg.value.
     * @param to address to send the FXD to.
     * @param minFxdOut Minimum accepted FXD for a successful fund.
     */
    function fund(address to, uint256 minFxdOut)
        external
        payable
        override
        returns (uint256 fxdOut)
    {
        fxdOut = _fundFxd(to, minFxdOut);
    }

    /**
     * @notice Defunds the pool by redeeming FXD in exchange for equivalent XDC from the pool.
     * @param from address to deduct the FXD from.
     * @param to address to send the XDC to.
     * @param fxdToBurn Amount of FXD to burn.
     * @param minXdcOut Minimum accepted XDC for a successful defund.
     */
    function defund(
        address from,
        address payable to,
        uint256 fxdToBurn,
        uint256 minXdcOut
    )
        external
        override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint256 xdcOut)
    {
        xdcOut = _defundFxd(from, to, fxdToBurn, minXdcOut);
    }

    /**
     * @notice Defunds the pool by redeeming FXD from an arbitrary address in exchange for equivalent XDC from the pool.
     * Called only by the FXD contract, when FXD is sent to it.
     * @param from address to deduct the FXD from.
     * @param to address to send the XDC to.
     * @param fxdToBurn Amount of FXD to burn.
     * @param minXdcOut Minimum accepted XDC for a successful defund.
     */
    function defundFromFXD(
        address from,
        address payable to,
        uint256 fxdToBurn,
        uint256 minXdcOut
    ) external override returns (uint256 xdcOut) {
        require(msg.sender == address(fxd), "Restricted to FXD");
        xdcOut = _defundFxd(from, to, fxdToBurn, minXdcOut);
    }

    /**
     * @notice If anyone sends XDC here, assume they intend it as a `mint`.
     * If decimals 8 to 11 (included) of the amount of XDC received are `0000` then the next 7 will
     * be parsed as the minimum XDC price accepted, with 2 digits before and 5 digits after the comma.
     */
    receive() external payable {
        _mintSxd(msg.sender, MinOut.parseMinTokenOut(msg.value));
    }

    /**
     * @notice If a user sends SXD tokens directly to this contract (or to the FXD contract), assume they intend it as a `burn`.
     * If using `transfer`/`transferFrom` as `burn`, and if decimals 8 to 11 (included) of the amount transferred received
     * are `0000` then the next 7 will be parsed as the maximum SXD price accepted, with 5 digits before and 2 digits after the comma.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (
            recipient == address(this) ||
            recipient == address(fxd) ||
            recipient == address(0)
        ) {
            _burnSdx(
                sender,
                payable(sender),
                amount,
                MinOut.parseMinXdcOut(amount)
            );
        } else {
            super._transfer(sender, recipient, amount);
        }
    }

    /** INTERNAL TRANSACTIONAL FUNCTIONS */

    function _mintSxd(address to, uint256 minSxdOut)
        internal
        returns (uint256 sxdOut)
    {
        // 1. Check that fund() has been called first - no minting before funding:
        uint256 rawXdcInPool = xdcPool();
        uint256 xdcInPool = rawXdcInPool.sub(msg.value); // Backing out the XDC just received, which our calculations should ignore
        require(xdcInPool > 0, "Fund before minting");

        // 2. Calculate sxdOut:
        uint256 xdcSxdPrice = cacheLatestPrice();
        uint256 sxdTotalSupply = totalSupply();
        uint256 oldDebtRatio = debtRatio(
            xdcSxdPrice,
            xdcInPool,
            sxdTotalSupply
        );
        sxdOut = sdxFromMint(xdcSxdPrice, msg.value, xdcInPool, sxdTotalSupply);
        require(sxdOut >= minSxdOut, "Limit not reached");

        // 3. Update state and mint the user's new SXD:
        uint256 newDebtRatio = debtRatio(
            xdcSxdPrice,
            rawXdcInPool,
            sxdTotalSupply.add(sxdOut)
        );
        _updateBuySellAdjustmentIfNeeded(
            oldDebtRatio,
            newDebtRatio,
            buySellAdjustment()
        );
        _mint(to, sxdOut);
    }

    function _burnSdx(
        address from,
        address payable to,
        uint256 sxdToBurn,
        uint256 minXdcOut
    ) internal returns (uint256 xdcOut) {
        // 1. Calculate xdcOut:
        uint256 xdcSxdPrice = cacheLatestPrice();
        uint256 xdcInPool = xdcPool();
        uint256 sxdTotalSupply = totalSupply();
        uint256 oldDebtRatio = debtRatio(
            xdcSxdPrice,
            xdcInPool,
            sxdTotalSupply
        );
        xdcOut = xdcFromBurn(xdcSxdPrice, sxdToBurn, xdcInPool, sxdTotalSupply);
        require(xdcOut >= minXdcOut, "Limit not reached");

        // 2. Update state and return the user's XDC:
        uint256 newDebtRatio = debtRatio(
            xdcSxdPrice,
            xdcInPool.sub(xdcOut),
            sxdTotalSupply.sub(sxdToBurn)
        );
        require(newDebtRatio <= WAD, "Debt ratio too high");
        _burn(from, sxdToBurn);
        _updateBuySellAdjustmentIfNeeded(
            oldDebtRatio,
            newDebtRatio,
            buySellAdjustment()
        );
        to.sendValue(xdcOut);
    }

    function _fundFxd(address to, uint256 minFxdOut)
        internal
        returns (uint256 fxdOut)
    {
        // 1. Refresh mfbp:
        uint256 xdcSxdPrice = cacheLatestPrice();
        uint256 rawXdcInPool = xdcPool();
        uint256 xdcInPool = rawXdcInPool.sub(msg.value); // Backing out the XDC just received, which our calculations should ignore
        uint256 sxdTotalSupply = totalSupply();
        uint256 oldDebtRatio = debtRatio(
            xdcSxdPrice,
            xdcInPool,
            sxdTotalSupply
        );
        uint256 fxdTotalSupply = fxd.totalSupply();
        _updateMinFxdBuyPrice(oldDebtRatio, xdcInPool, fxdTotalSupply);

        // 2. Calculate fxdOut:
        uint256 adjustment = buySellAdjustment();
        fxdOut = fxdFromFund(
            xdcSxdPrice,
            msg.value,
            xdcInPool,
            sxdTotalSupply,
            fxdTotalSupply,
            adjustment
        );
        require(fxdOut >= minFxdOut, "Limit not reached");

        // 3. Update state and mint the user's new FXD:
        uint256 newDebtRatio = debtRatio(
            xdcSxdPrice,
            rawXdcInPool,
            sxdTotalSupply
        );
        _updateBuySellAdjustmentIfNeeded(
            oldDebtRatio,
            newDebtRatio,
            adjustment
        );
        fxd.mint(to, fxdOut);
    }

    function _defundFxd(
        address from,
        address payable to,
        uint256 fxdToBurn,
        uint256 minXdcOut
    ) internal returns (uint256 xdcOut) {
        // 1. Calculate xdcOut:
        uint256 xdcSxdPrice = cacheLatestPrice();
        uint256 xdcInPool = xdcPool();
        uint256 sxdTotalSupply = totalSupply();
        uint256 oldDebtRatio = debtRatio(
            xdcSxdPrice,
            xdcInPool,
            sxdTotalSupply
        );
        xdcOut = xdcFromDefund(
            xdcSxdPrice,
            fxdToBurn,
            xdcInPool,
            sxdTotalSupply
        );
        require(xdcOut >= minXdcOut, "Limit not reached");

        // 2. Update state and return the user's XDC:
        uint256 newDebtRatio = debtRatio(
            xdcSxdPrice,
            xdcInPool.sub(xdcOut),
            sxdTotalSupply
        );
        require(newDebtRatio <= MAX_DEBT_RATIO, "Max debt ratio breach");
        fxd.burn(from, fxdToBurn);
        _updateBuySellAdjustmentIfNeeded(
            oldDebtRatio,
            newDebtRatio,
            buySellAdjustment()
        );
        to.sendValue(xdcOut);
    }

    /**
     * @notice Set the min FXD price, based on the current oracle price and debt ratio. Emits a minFxdBuyPriceChanged event.
     * @dev The logic for calculating a new minFxdBuyPrice is as follows.  We want to set it to the FXD price, in XDC terms, at
     * which debt ratio was exactly MAX_DEBT_RATIO.  So we can assume:
     *
     *     sxdToXdc(totalSupply()) / xdcPool() = MAX_DEBT_RATIO, or in other words:
     *     sxdToXdc(totalSupply()) = MAX_DEBT_RATIO * xdcPool()
     *
     * And with this assumption, we calculate the FXD price (buffer / FXD qty) like so:
     *
     *     minFxdBuyPrice = xdcBuffer() / fxd.totalSupply()
     *                    = (xdcPool() - sxdToXdc(totalSupply())) / fxd.totalSupply()
     *                    = (xdcPool() - (MAX_DEBT_RATIO * xdcPool())) / fxd.totalSupply()
     *                    = (1 - MAX_DEBT_RATIO) * xdcPool() / fxd.totalSupply()
     */
    function _updateMinFxdBuyPrice(
        uint256 debtRatio_,
        uint256 xdcInPool,
        uint256 fxdTotalSupply
    ) internal {
        uint256 previous = minFxdBuyPriceStored.value;
        if (debtRatio_ <= MAX_DEBT_RATIO) {
            // We've dropped below (or were already below, whatev) max debt ratio
            if (previous != 0) {
                minFxdBuyPriceStored.timestamp = 0; // Clear mfbp
                minFxdBuyPriceStored.value = 0;
                emit minFxdBuyPriceChanged(previous, 0);
            }
        } else if (previous == 0) {
            // We were < max debt ratio, but have now crossed above - so set mfbp
            // See reasoning in @dev comment above
            minFxdBuyPriceStored.timestamp = uint32(block.timestamp);
            minFxdBuyPriceStored.value = uint224(
                (WAD - MAX_DEBT_RATIO).wadMulUp(xdcInPool).wadDivUp(
                    fxdTotalSupply
                )
            );
            emit minFxdBuyPriceChanged(previous, minFxdBuyPriceStored.value);
        }
    }

    /**
     * @notice Update the buy/sell adjustment factor, as of the current block time, after a price-moving operation.
     * @param oldDebtRatio The debt ratio before the operation (eg, mint()) was done
     * @param newDebtRatio The current, post-op debt ratio
     */
    function _updateBuySellAdjustmentIfNeeded(
        uint256 oldDebtRatio,
        uint256 newDebtRatio,
        uint256 oldAdjustment
    ) internal {
        if (oldDebtRatio != 0 && newDebtRatio != 0) {
            uint256 previous = buySellAdjustmentStored.value;
            // Eg: if a user operation reduced debt ratio from 70% to 50%, it was either a fund() or a burn().  These are both
            // "long-XDC" operations.  So we can take (old / new)**2 = (70% / 50%)**2 = 1.4**2 = 1.96 as the ratio by which to
            // increase buySellAdjustment, which is intended as a measure of "how long-XDC recent user activity has been":
            uint256 newAdjustment = oldAdjustment
                .mul(oldDebtRatio)
                .mul(oldDebtRatio)
                .div(newDebtRatio)
                .div(newDebtRatio);
            buySellAdjustmentStored.timestamp = uint32(block.timestamp);
            buySellAdjustmentStored.value = uint224(newAdjustment);
            emit BuySellAdjustmentChanged(previous, newAdjustment);
        }
    }

    /** PUBLIC AND INTERNAL VIEW FUNCTIONS **/

    /**
     * @notice Total amount of XDC in the pool (ie, in the contract).
     * @return pool XDC pool
     */
    function xdcPool() public view returns (uint256 pool) {
        pool = address(this).balance;
    }

    /**
     * @notice Calculate the amount of XDC in the buffer.
     * @return buffer XDC buffer
     */
    function xdcBuffer(
        uint256 xdcSxdPrice,
        uint256 xdcInPool,
        uint256 sxdTotalSupply,
        WadMath.Round upOrDown
    ) internal pure returns (int256 buffer) {
        // Reverse the input upOrDown, since we're using it for sxdToXdc(), which will be *subtracted* from xdcInPool below:
        WadMath.Round downOrUp = (
            upOrDown == WadMath.Round.Down
                ? WadMath.Round.Up
                : WadMath.Round.Down
        );
        buffer =
            int256(xdcInPool) -
            int256(sxdToXdc(xdcSxdPrice, sxdTotalSupply, downOrUp));
        require(buffer <= int256(xdcInPool), "Underflow error");
    }

    /**
     * @notice Calculate debt ratio for a given XDC to SXD price: ratio of the outstanding SXD (amount of SXD in total supply), to
     * the current XDC pool amount.
     * @return ratio Debt ratio
     */
    function debtRatio(
        uint256 xdcSxdPrice,
        uint256 xdcInPool,
        uint256 sxdTotalSupply
    ) internal pure returns (uint256 ratio) {
        uint256 xdcPoolValueInUsd = xdcInPool.wadMulDown(xdcSxdPrice);
        ratio = (
            xdcInPool == 0 ? 0 : sxdTotalSupply.wadDivUp(xdcPoolValueInUsd)
        );
    }

    /**
     * @notice Convert XDC amount to SXD using a XDC/USD price.
     * @param xdcAmount The amount of XDC to convert
     * @return sxdOut The amount of SXD
     */
    function xdcToSxd(
        uint256 xdcSxdPrice,
        uint256 xdcAmount,
        WadMath.Round upOrDown
    ) internal pure returns (uint256 sxdOut) {
        sxdOut = xdcAmount.wadMul(xdcSxdPrice, upOrDown);
    }

    /**
     * @notice Convert SXD amount to XDC using a XDC/USD price.
     * @param sxdAmount The amount of SXD to convert
     * @return xdcOut The amount of XDC
     */
    function sxdToXdc(
        uint256 xdcSxdPrice,
        uint256 sxdAmount,
        WadMath.Round upOrDown
    ) internal pure returns (uint256 xdcOut) {
        xdcOut = sxdAmount.wadDiv(xdcSxdPrice, upOrDown);
    }

    /**
     * @notice Calculate the *marginal* price of SXD (in XDC terms) - that is, of the next unit, before the price start sliding.
     * @return price SXD price in XDC terms
     */
    function sdxPrice(Side side, uint256 xdcSxdPrice)
        internal
        view
        returns (uint256 price)
    {
        WadMath.Round upOrDown = (
            side == Side.Buy ? WadMath.Round.Up : WadMath.Round.Down
        );
        price = sxdToXdc(xdcSxdPrice, WAD, upOrDown);

        uint256 adjustment = buySellAdjustment();
        if (
            (side == Side.Buy && adjustment < WAD) ||
            (side == Side.Sell && adjustment > WAD)
        ) {
            price = price.wadDiv(adjustment, upOrDown);
        }
    }

    /**
     * @notice Calculate the *marginal* price of FXD (in XDC terms) - that is, of the next unit, before the price start sliding.
     * @return price FXD price in XDC terms
     */
    function fxdPrice(
        Side side,
        uint256 xdcSxdPrice,
        uint256 xdcInPool,
        uint256 sxdTotalSupply,
        uint256 fxdTotalSupply,
        uint256 adjustment
    ) internal view returns (uint256 price) {
        WadMath.Round upOrDown = (
            side == Side.Buy ? WadMath.Round.Up : WadMath.Round.Down
        );
        if (fxdTotalSupply == 0) {
            return sxdToXdc(xdcSxdPrice, WAD, upOrDown); // if no FXD issued yet, default fxdPrice to 1 USD (in XDC terms)
        }
        int256 buffer = xdcBuffer(
            xdcSxdPrice,
            xdcInPool,
            sxdTotalSupply,
            upOrDown
        );
        price = (
            buffer <= 0 ? 0 : uint256(buffer).wadDiv(fxdTotalSupply, upOrDown)
        );

        if (side == Side.Buy) {
            if (adjustment > WAD) {
                price = price.wadMulUp(adjustment);
            }
            // Floor the buy price at minFxdBuyPrice:
            uint256 mfbp = minFxdBuyPrice();
            if (price < mfbp) {
                price = mfbp;
            }
        } else {
            if (adjustment < WAD) {
                price = price.wadMulDown(adjustment);
            }
        }
    }

    /**
     * @notice How much SXD a minter currently gets back for xdcIn XDC, accounting for adjustment and sliding prices.
     * @param xdcIn The amount of XDC passed to mint()
     * @return sxdOut The amount of SXD to receive in exchange
     */
    function sdxFromMint(
        uint256 xdcSxdPrice,
        uint256 xdcIn,
        uint256 xdcQty0,
        uint256 sxdQty0
    ) internal view returns (uint256 sxdOut) {
        // Mint SXD at a sliding-up SXD price (ie, at a sliding-down XDC price).  **BASIC RULE:** anytime debtRatio() changes by
        // factor k (here > 1), XDC price changes by factor 1/k**2 (ie, SXD price, in XDC terms, changes by factor k**2).
        // (Earlier versions of this logic scaled XDC price based on change in xdcPool(), or change in xdcPool()**2: the latter
        // gives simpler math - no cbrt() - but doesn't let mint/burn offset fund/defund, which debtRatio()**2 nicely does.)
        uint256 sdxPrice0 = sdxPrice(Side.Buy, xdcSxdPrice);
        if (sxdQty0 == 0) {
            // No SXD in the system, so debtRatio() == 0 which breaks the integral below - skip sliding-prices this time:
            sxdOut = xdcIn.wadDivDown(sdxPrice0);
        } else {
            uint256 xdcQty1 = xdcQty0.add(xdcIn);

            // Math: this is an integral - sum of all SXD minted at a sliding-down XDC price:
            // u - u_0 = ((((e / e_0)**3 - 1) * e_0 / ubp_0 + u_0) * u_0**2)**(1/3) - u_0
            uint256 integralFirstPart = xdcQty1
                .wadDivDown(xdcQty0)
                .wadCubedDown()
                .sub(WAD)
                .mul(xdcQty0)
                .div(sdxPrice0)
                .add(sxdQty0);
            sxdOut = integralFirstPart
                .wadMulDown(sxdQty0.wadSquaredDown())
                .wadCbrtDown()
                .sub(sxdQty0);
        }
    }

    /**
     * @notice How much XDC a burner currently gets from burning sxdIn SXD, accounting for adjustment and sliding prices.
     * @param sxdIn The amount of SXD passed to burn()
     * @return xdcOut The amount of XDC to receive in exchange
     */
    function xdcFromBurn(
        uint256 xdcSxdPrice,
        uint256 sxdIn,
        uint256 xdcQty0,
        uint256 sxdQty0
    ) internal view returns (uint256 xdcOut) {
        // Burn SXD at a sliding-down SXD price (ie, a sliding-up XDC price):
        uint256 sdxPrice0 = sdxPrice(Side.Sell, xdcSxdPrice);
        uint256 sxdQty1 = sxdQty0.sub(sxdIn);

        // Math: this is an integral - sum of all SXD burned at a sliding price.  Follows the same mathematical invariant as
        // above: if debtRatio() *= k (here, k < 1), XDC price *= 1/k**2, ie, SXD price in XDC terms *= k**2.
        // e_0 - e = e_0 - (e_0**2 * (e_0 - usp_0 * u_0 * (1 - (u / u_0)**3)))**(1/3)
        uint256 integralFirstPart = sdxPrice0.wadMulDown(sxdQty0).wadMulDown(
            WAD.sub(sxdQty1.wadDivUp(sxdQty0).wadCubedUp())
        );
        xdcOut = xdcQty0.sub(
            xdcQty0
                .wadSquaredUp()
                .wadMulUp(xdcQty0.sub(integralFirstPart))
                .wadCbrtUp()
        );
    }

    /**
     * @notice How much FXD a funder currently gets back for xdcIn XDC, accounting for adjustment and sliding prices.
     * @param xdcIn The amount of XDC passed to fund()
     * @return fxdOut The amount of FXD to receive in exchange
     */
    function fxdFromFund(
        uint256 xdcSxdPrice,
        uint256 xdcIn,
        uint256 xdcQty0,
        uint256 sxdQty0,
        uint256 fxdQty0,
        uint256 adjustment
    ) internal view returns (uint256 fxdOut) {
        // Create FXD at a sliding-up FXD price:
        uint256 fxdPrice0 = fxdPrice(
            Side.Buy,
            xdcSxdPrice,
            xdcQty0,
            sxdQty0,
            fxdQty0,
            adjustment
        );
        if (sxdQty0 == 0) {
            // No SXD in the system - skip sliding-prices:
            fxdOut = xdcIn.wadDivDown(fxdPrice0);
        } else {
            // Math: f - f_0 = e_0 * (e - e_0) / (e * fbp_0)
            uint256 xdcQty1 = xdcQty0.add(xdcIn);
            fxdOut = xdcQty0.mul(xdcIn).div(xdcQty1.wadMulUp(fxdPrice0));
        }
    }

    /**
     * @notice How much XDC a defunder currently gets back for fxdIn FXD, accounting for adjustment and sliding prices.
     * @param fxdIn The amount of FXD passed to defund()
     * @return xdcOut The amount of XDC to receive in exchange
     */
    function xdcFromDefund(
        uint256 xdcSxdPrice,
        uint256 fxdIn,
        uint256 xdcQty0,
        uint256 sxdQty0
    ) internal view returns (uint256 xdcOut) {
        // Burn FXD at a sliding-down FXD price:
        uint256 fxdQty0 = fxd.totalSupply();
        uint256 fxdPrice0 = fxdPrice(
            Side.Sell,
            xdcSxdPrice,
            xdcQty0,
            sxdQty0,
            fxdQty0,
            buySellAdjustment()
        );
        if (sxdQty0 == 0) {
            // No SXD in the system - skip sliding-prices:
            xdcOut = fxdIn.wadMulDown(fxdPrice0);
        } else {
            // Math: e_0 - e = e_0 * (f_0 - f) * fsp_0 / (e_0 + (f_0 - f) * fsp_0)
            xdcOut = xdcQty0.mul(fxdIn.wadMulDown(fxdPrice0)).div(
                xdcQty0.add(fxdIn.wadMulUp(fxdPrice0))
            );
        }
    }

    /**
     * @notice The current min FXD buy price, equal to the stored value decayed by time since minFxdBuyPriceTimestamp.
     * @return mfbp The minFxdBuyPrice, in XDC terms
     */
    function minFxdBuyPrice() public view returns (uint256 mfbp) {
        if (minFxdBuyPriceStored.value != 0) {
            uint256 numHalvings = block
                .timestamp
                .sub(minFxdBuyPriceStored.timestamp)
                .wadDivDown(MIN_FXD_BUY_PRICE_HALF_LIFE);
            uint256 decayFactor = numHalvings.wadHalfExp();
            mfbp = uint256(minFxdBuyPriceStored.value).wadMulUp(decayFactor);
        } // Otherwise just returns 0
    }

    /**
     * @notice The current buy/sell adjustment, equal to the stored value decayed by time since buySellAdjustmentTimestamp.  This
     * adjustment is intended as a measure of "how long-XDC recent user activity has been", so that we can slide price
     * accordingly: if recent activity was mostly long-XDC (fund() and burn()), raise FXD buy price/reduce SXD sell price; if
     * recent activity was short-XDC (defund() and mint()), reduce FXD sell price/raise SXD buy price.  We use "it reduced debt
     * ratio" as a rough proxy for "the operation was long-XDC".
     *
     * (There is one odd case: when debt ratio > 100%, a *short*-XDC mint() will actually reduce debt ratio.  This does no real
     * harm except to make fast-succession mint()s and fund()s in such > 100% cases a little more expensive than they would be.)
     *
     * @return adjustment The sliding-price buy/sell adjustment
     */
    function buySellAdjustment() public view returns (uint256 adjustment) {
        uint256 numHalvings = block
            .timestamp
            .sub(buySellAdjustmentStored.timestamp)
            .wadDivDown(BUY_SELL_ADJUSTMENT_HALF_LIFE);
        uint256 decayFactor = numHalvings.wadHalfExp(10);
        // Here we use the idea that for any b and 0 <= p <= 1, we can crudely approximate b**p by 1 + (b-1)p = 1 + bp - p.
        // Eg: 0.6**0.5 pulls 0.6 "about halfway" to 1 (0.8); 0.6**0.25 pulls 0.6 "about 3/4 of the way" to 1 (0.9).
        // So b**p =~ b + (1-p)(1-b) = b + 1 - b - p + bp = 1 + bp - p.
        // (Don't calculate it as 1 + (b-1)p because we're using uints, b-1 can be negative!)
        adjustment = WAD
            .add(uint256(buySellAdjustmentStored.value).wadMulDown(decayFactor))
            .sub(decayFactor);
    }

    /** EXTERNAL VIEW FUNCTIONS */

    /**
     * @notice Calculate the amount of XDC in the buffer.
     * @return buffer XDC buffer
     */
    function xdcBuffer(WadMath.Round upOrDown)
        external
        view
        returns (int256 buffer)
    {
        buffer = xdcBuffer(latestPrice(), xdcPool(), totalSupply(), upOrDown);
    }

    /**
     * @notice Convert XDC amount to SXD using the latest oracle XDC/USD price.
     * @param xdcAmount The amount of XDC to convert
     * @return sxdOut The amount of SXD
     */
    function xdcToSxd(uint256 xdcAmount, WadMath.Round upOrDown)
        external
        view
        returns (uint256 sxdOut)
    {
        sxdOut = xdcToSxd(latestPrice(), xdcAmount, upOrDown);
    }

    /**
     * @notice Convert SXD amount to XDC using the latest oracle XDC/USD price.
     * @param sxdAmount The amount of SXD to convert
     * @return xdcOut The amount of XDC
     */
    function sxdToXdc(uint256 sxdAmount, WadMath.Round upOrDown)
        external
        view
        returns (uint256 xdcOut)
    {
        xdcOut = sxdToXdc(latestPrice(), sxdAmount, upOrDown);
    }

    /**
     * @notice Calculate debt ratio.
     * @return ratio Debt ratio
     */
    function debtRatio() external view returns (uint256 ratio) {
        ratio = debtRatio(latestPrice(), xdcPool(), totalSupply());
    }

    /**
     * @notice Calculate the *marginal* price of SXD (in XDC terms) - that is, of the next unit, before the price start sliding.
     * @return price SXD price in XDC terms
     */
    function sdxPrice(Side side) external view returns (uint256 price) {
        price = sdxPrice(side, latestPrice());
    }

    /**
     * @notice Calculate the *marginal* price of FXD (in XDC terms) - that is, of the next unit, before the price start sliding.
     * @return price FXD price in XDC terms
     */
    function fxdPrice(Side side) external view returns (uint256 price) {
        price = fxdPrice(
            side,
            latestPrice(),
            xdcPool(),
            totalSupply(),
            fxd.totalSupply(),
            buySellAdjustment()
        );
    }
}
