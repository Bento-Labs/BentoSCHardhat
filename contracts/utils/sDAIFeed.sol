// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {AggregatorV3Interface} from "../interfaces/chainlink/AggregatorV3Interface.sol";
import {AggregatorInterface} from "../interfaces/chainlink/AggregatorInterface.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract sDAIFeed is AggregatorV3Interface {
    using SafeCast for int256;

    AggregatorInterface public immutable savingsDaiOracle;
    uint8 private constant DECIMALS = 8;

    constructor(address _savingsDaiOracle) {
        savingsDaiOracle = AggregatorInterface(_savingsDaiOracle);
    }

    function decimals() external pure override returns (uint8) {
        return DECIMALS;
    }

    function description() external pure override returns (string memory) {
        return "sDAI / USD";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId) external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        roundId = _roundId;
        answer = savingsDaiOracle.getAnswer(roundId);
        startedAt = 0;
        updatedAt = savingsDaiOracle.getTimestamp(roundId);
        answeredInRound = 0;
    }

    function latestRoundData() external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        roundId = uint80(savingsDaiOracle.latestRound());
        answer = savingsDaiOracle.latestAnswer();
        updatedAt = savingsDaiOracle.latestTimestamp();
        startedAt = 0; // We don't have a separate startedAt, so we use updatedAt
        answeredInRound = 0; // We don't have a separate answeredInRound, so we use roundId
    }
}