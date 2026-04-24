// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IPriceOracle } from "./interfaces/IPriceOracle.sol";
import { AggregatorV3Interface } from "./lib/AggregatorV3Interface.sol";

/// @title PriceOracle
/// @notice Quotes name registration prices in wei using a Chainlink ETH/USD feed.
/// @dev Flat-rate model: all names with length >= MIN_NAME_LENGTH cost the same
///      USD price per year. Shorter names revert with NameTooShort.
///
///      Price formula (no overflow risk — intermediate values fit uint256):
///        baseWei = basePriceUsd * duration * 1e18 / (365 days * ethUsdPrice)
///      where basePriceUsd and ethUsdPrice are both in 1e8 units (Chainlink scale),
///      so they cancel and the result is pure wei.
contract PriceOracle is IPriceOracle, Ownable2Step {
    uint256 public constant MIN_NAME_LENGTH = 3;
    uint256 private constant YEAR = 365 days;

    /// @dev Chainlink ETH/USD feed (8 decimals on all networks)
    AggregatorV3Interface public priceFeed;

    /// @dev Maximum age of a Chainlink answer before it's considered stale (default: 1 hour)
    uint256 public maxStaleness;

    /// @dev Annual registration price in 1e8 USD units (e.g. 5_00000000 = $5.00/year)
    uint256 public basePriceUsd;

    constructor(
        address feed,
        uint256 _maxStaleness,
        uint256 _basePriceUsd,
        address initialOwner
    ) Ownable(initialOwner) {
        priceFeed = AggregatorV3Interface(feed);
        maxStaleness = _maxStaleness;
        basePriceUsd = _basePriceUsd;
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
        // basePriceUsd (1e8 USD/year) * duration (seconds) * 1e18 (wei/ETH)
        // ─────────────────────────────────────────────────────────────────
        //   YEAR (seconds/year)          * ethUsd (1e8 USD/ETH)
        // The two 1e8 factors cancel, leaving wei.
        uint256 base = (basePriceUsd * duration * 1e18) / (YEAR * ethUsd);
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
        return basePriceUsd;
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

    function setBasePriceUsd(uint256 usd) external onlyOwner {
        emit BasePriceUpdated(basePriceUsd, usd);
        basePriceUsd = usd;
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
