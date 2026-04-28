// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IPriceOracle
/// @notice Prices name registrations in wei. Two-tier pricing model.
/// @dev Uses Chainlink ETH/USD price feed to translate USD-denominated prices
///      into wei at the time of quotation. Staleness-checked.
///
/// Pricing model (configurable by owner):
///   length 1-2                       → reserved (returns NameTooShort)
///   length 3+, duration < 365 days   → monthlyPriceUsd per 30 days
///   length 3+, duration >= 365 days  → annualPriceUsd per year
///
/// Design choice: Oniym uses flat pricing (no length-based premiums) to
/// differentiate from ENS's tiered model and fit Base's price-sensitive user
/// base. This means short names WILL be squatted by bots on launch — treat
/// valuable short names as launch-day scarcity, not a pricing problem.
///
/// Rent vs buy: all registrations are RENT (finite duration). Expired names
/// return to the pool after a grace period.
interface IPriceOracle {
    // ---------------------------------------------------------------
    //                           STRUCTS
    // ---------------------------------------------------------------

    /// @notice Price breakdown returned by {price}
    /// @param base Cost of the registration itself (in wei)
    /// @param premium Reserved for future post-expiry auction decay. Always 0 today.
    struct Price {
        uint256 base;
        uint256 premium;
    }

    // ---------------------------------------------------------------
    //                           EVENTS
    // ---------------------------------------------------------------

    event PriceFeedUpdated(address indexed previous, address indexed next);
    event MaxStalenessUpdated(uint256 previous, uint256 next);
    event MonthlyPriceUpdated(uint256 previousUsd, uint256 nextUsd);
    event AnnualPriceUpdated(uint256 previousUsd, uint256 nextUsd);

    // ---------------------------------------------------------------
    //                           ERRORS
    // ---------------------------------------------------------------

    /// @notice Oracle price feed returned a stale answer
    error StalePriceFeed(uint256 updatedAt, uint256 staleAfter);

    /// @notice Oracle price feed returned a non-positive answer
    error InvalidPriceFeed(int256 answer);

    /// @notice Name length is too short to be registered
    error NameTooShort(uint256 length);

    // ---------------------------------------------------------------
    //                           READS
    // ---------------------------------------------------------------

    /// @notice Quote the total price for registering a name for a duration
    /// @param name The label string (e.g. "kyy")
    /// @param expires Current expiry of the name (0 if fresh registration) —
    ///                used for premium decay calculation (reserved)
    /// @param duration Registration duration in seconds
    /// @return priceInfo Base and premium components, both in wei
    function price(
        string calldata name,
        uint256 expires,
        uint256 duration
    ) external view returns (Price memory priceInfo);

    /// @notice Current ETH/USD price from Chainlink, scaled to 1e8
    function ethUsdPrice() external view returns (uint256);

    /// @notice Effective annual USD price in 1e8 units for a given name length
    /// @dev Returns annualPriceUsd for valid lengths, 0 for too-short names.
    function priceFor(uint256 length) external view returns (uint256 usdPerYear);

    /// @notice Quote total price for a USDC payment (6-decimal units)
    /// @dev Same two-tier logic as {price} but returns USDC amount instead of wei.
    ///      No Chainlink feed required — USDC is 1:1 with USD.
    function priceUsdc(
        string calldata name,
        uint256 expires,
        uint256 duration
    ) external view returns (uint256 usdcAmount);
}
