// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title Fixed point arithmetic library
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 */
library WadMath {
    using SafeMath for uint256;

    enum Round {
        Down,
        Up
    }

    uint256 private constant WAD = 10**18;
    uint256 private constant WAD_MINUS_1 = WAD - 1;
    uint256 private constant WAD_SQUARED = WAD * WAD;
    uint256 private constant WAD_SQUARED_MINUS_1 = WAD_SQUARED - 1;
    uint256 private constant WAD_OVER_10 = WAD / 10;
    uint256 private constant WAD_OVER_20 = WAD / 20;
    uint256 private constant HALF_TO_THE_ONE_TENTH = 933032991536807416;
    uint256 private constant TWO_WAD = 2 * WAD;

    function wadMul(
        uint256 x,
        uint256 y,
        Round upOrDown
    ) internal pure returns (uint256) {
        return upOrDown == Round.Down ? wadMulDown(x, y) : wadMulUp(x, y);
    }

    function wadMulDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return x.mul(y) / WAD;
    }

    function wadMulUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x.mul(y)).add(WAD_MINUS_1) / WAD;
    }

    function wadSquaredDown(uint256 x) internal pure returns (uint256) {
        return (x.mul(x)) / WAD;
    }

    function wadSquaredUp(uint256 x) internal pure returns (uint256) {
        return (x.mul(x)).add(WAD_MINUS_1) / WAD;
    }

    function wadCubedDown(uint256 x) internal pure returns (uint256) {
        return (x.mul(x)).mul(x) / WAD_SQUARED;
    }

    function wadCubedUp(uint256 x) internal pure returns (uint256) {
        return ((x.mul(x)).mul(x)).add(WAD_SQUARED_MINUS_1) / WAD_SQUARED;
    }

    function wadDiv(
        uint256 x,
        uint256 y,
        Round upOrDown
    ) internal pure returns (uint256) {
        return upOrDown == Round.Down ? wadDivDown(x, y) : wadDivUp(x, y);
    }

    function wadDivDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x.mul(WAD)).div(y);
    }

    function wadDivUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return ((x.mul(WAD)).add(y - 1)).div(y); // Can use "-" instead of sub() since div(y) will catch y = 0 case anyway
    }

    function wadHalfExp(uint256 power) internal pure returns (uint256) {
        return wadHalfExp(power, uint256(1));
    }

    //returns a loose but "gas-efficient" approximation of 0.5**power, where power is rounded to the nearest 0.1, and is capped
    //at maxPower.  Note that power is WAD-scaled (eg, 2.7364 * WAD), but maxPower is just a plain unscaled uint (eg, 10).
    function wadHalfExp(uint256 power, uint256 maxPower)
        internal
        pure
        returns (uint256)
    {
        require(power >= 0, "power must be positive");
        uint256 powerInTenths = power.add(WAD_OVER_20) / WAD_OVER_10;
        require(powerInTenths >= 0, "powerInTenths must be positive");
        if (powerInTenths / 10 > maxPower) {
            return 0;
        }
        return wadPow(HALF_TO_THE_ONE_TENTH, powerInTenths);
    }

    // Adapted from rpow() in https://github.com/dapphub/ds-math/blob/master/src/math.sol - thank you!
    //
    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function wadPow(uint256 x, uint256 n) internal pure returns (uint256 z) {
        z = n % 2 != 0 ? x : WAD;

        for (n /= 2; n != 0; n /= 2) {
            x = wadSquaredDown(x);

            if (n % 2 != 0) {
                z = wadMulDown(z, x);
            }
        }
    }

    // Using Newton's method (see eg https://stackoverflow.com/a/8827111/3996653), but with WAD fixed-point math.
    function wadCbrtDown(uint256 y) internal pure returns (uint256 root) {
        if (y > 0) {
            uint256 newRoot = y.add(TWO_WAD) / 3;
            uint256 yTimesWadSquared = y.mul(WAD_SQUARED);
            do {
                root = newRoot;
                newRoot =
                    (root + root + (yTimesWadSquared / (root * root))) /
                    3;
            } while (newRoot < root);
        }
        //require(root**3 <= y.mul(WAD_SQUARED) && y.mul(WAD_SQUARED) < (root + 1)**3);
    }

    function wadCbrtUp(uint256 y) internal pure returns (uint256 root) {
        root = wadCbrtDown(y);
        // The only case where wadCbrtUp(y) *isn't* equal to wadCbrtDown(y) + 1 is when y is a perfect cube; so check for that.
        // These "*"s are safe because: 1. root**3 <= y.mul(WAD_SQUARED), and 2. y.mul(WAD_SQUARED) is calculated (safely) above.
        if (root * root * root != y * WAD_SQUARED) {
            ++root;
        }
        //require((root - 1)**3 < y.mul(WAD_SQUARED) && y.mul(WAD_SQUARED) <= root**3);
    }
}
