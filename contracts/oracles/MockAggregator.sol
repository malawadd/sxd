pragma solidity ^0.8.17;

contract MockAggregatorV3 {
    int256 internal _answer;

    function set(int256 value) external {
        _answer = value;
    }

    function latestRoundData()
        public
        view
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (0, _answer, 0, 0, 0);
    }
}
