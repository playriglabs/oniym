// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IPriceOracle } from "./interfaces/IPriceOracle.sol";
import { AggregatorV3Interface } from "./lib/AggregatorV3Interface.sol";

/// @title PriceOracle
/// @notice Quotes name registration prices in wei using a Chainlink ETH/USD feed.
/// @dev Two-tier model:
///      - duration < 365 days  → monthly rate ($3/month by default)
///      - duration >= 365 days → annual rate ($15/year by default, cheaper than 12× monthly)
///
///      Monthly formula (no overflow risk — intermediate values fit uint256):
///        base = monthlyPriceUsd * duration * 1e18 / (MONTH * ethUsdPrice)
///
///      Annual formula (full years + monthly remainder):
///        base = annualPriceUsd * years * 1e18 / ethUsdPrice
///             + monthlyPriceUsd * rem * 1e18 / (MONTH * ethUsdPrice)
///
///      Both monthlyPriceUsd and ethUsdPrice are in 1e8 units (Chainlink scale),
///      so they cancel and the result is pure wei.
contract PriceOracle is IPriceOracle, Ownable2Step {
    uint256 public constant MIN_NAME_LENGTH = 3;
    uint256 private constant MONTH = 30 days;
    uint256 private constant YEAR = 365 days;

    /// @dev Chainlink ETH/USD feed (8 decimals on all networks)
    AggregatorV3Interface public priceFeed;

    /// @dev Maximum age of a Chainlink answer before it's considered stale (default: 1 hour)
    uint256 public maxStaleness;

    /// @dev Monthly registration price in 1e8 USD units (e.g. 3_00000000 = $3.00/month)
    uint256 public monthlyPriceUsd;

    /// @dev Annual registration price in 1e8 USD units (e.g. 15_00000000 = $15.00/year)
    uint256 public annualPriceUsd;

    constructor(
        address feed,
        uint256 _maxStaleness,
        uint256 _monthlyPriceUsd,
        uint256 _annualPriceUsd,
        address initialOwner
    ) Ownable(initialOwner) {
        priceFeed = AggregatorV3Interface(feed);
        maxStaleness = _maxStaleness;
        monthlyPriceUsd = _monthlyPriceUsd;
        annualPriceUsd = _annualPriceUsd;
    }

    // ---------------------------------------------------------------
    //                           READS
    // ---------------------------------------------------------------

    /// @inheritdoc IPriceOracle
    function price(
        string calldata name,
        uint256, /* expires — reserved for future premium decay */
        uint256 duration
    ) external view override returns (Price memory) {
        uint256 len = _strlen(name);
        if (len < MIN_NAME_LENGTH) revert NameTooShort(len);

        uint256 ethUsd = ethUsdPrice();
        uint256 base;

        if (duration >= YEAR) {
            uint256 numYears = duration / YEAR;
            uint256 rem = duration % YEAR;
            // Annual rate for full years, monthly rate for remaining seconds
            base = (annualPriceUsd * numYears * 1e18) / ethUsd;
            if (rem > 0) {
                base += (monthlyPriceUsd * rem * 1e18) / (MONTH * ethUsd);
            }
        } else {
            // Monthly rate for sub-year durations
            base = (monthlyPriceUsd * duration * 1e18) / (MONTH * ethUsd);
        }

        return Price({ base: base, premium: 0 });
    }

    /// @inheritdoc IPriceOracle
    function ethUsdPrice() public view override returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();
        uint256 staleAfter = updatedAt + maxStaleness;
        if (block.timestamp > staleAfter) {
            revert StalePriceFeed(updatedAt, staleAfter);
        }
        if (answer <= 0) revert InvalidPriceFeed(answer);
        // forge-lint: disable-next-line(unsafe-typecast) — safe: answer > 0 verified above
        return uint256(answer);
    }

    /// @inheritdoc IPriceOracle
    function priceFor(uint256 length) external view override returns (uint256) {
        if (length < MIN_NAME_LENGTH) return 0;
        return annualPriceUsd;
    }

    // ---------------------------------------------------------------
    //                           ADMIN
    // ---------------------------------------------------------------

    function setPriceFeed(address feed) external onlyOwner {
        emit PriceFeedUpdated(address(priceFeed), feed);
        priceFeed = AggregatorV3Interface(feed);
    }

    function setMaxStaleness(uint256 staleness) external onlyOwner {
        emit MaxStalenessUpdated(maxStaleness, staleness);
        maxStaleness = staleness;
    }

    function setMonthlyPrice(uint256 usd) external onlyOwner {
        emit MonthlyPriceUpdated(monthlyPriceUsd, usd);
        monthlyPriceUsd = usd;
    }

    function setAnnualPrice(uint256 usd) external onlyOwner {
        emit AnnualPriceUpdated(annualPriceUsd, usd);
        annualPriceUsd = usd;
    }

    // ---------------------------------------------------------------
    //                          INTERNAL
    // ---------------------------------------------------------------

    /// @dev Byte-length of a UTF-8 string. For ASCII names this equals character count.
    ///      Non-ASCII labels are rejected at the SDK/UI layer (UTS-46 normalization).
    function _strlen(string calldata s) internal pure returns (uint256) {
        return bytes(s).length;
    }
}
