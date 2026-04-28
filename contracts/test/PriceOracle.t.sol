// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { PriceOracle } from "../src/PriceOracle.sol";
import { IPriceOracle } from "../src/interfaces/IPriceOracle.sol";

/// @dev Minimal mock Chainlink feed — configurable answer and updatedAt.
contract MockFeed {
    int256 public answer;
    uint256 public updatedAt;
    uint8 public decimals = 8;

    constructor(int256 _answer) {
        answer = _answer;
        updatedAt = block.timestamp;
    }

    function setAnswer(int256 _answer) external {
        answer = _answer;
    }

    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, answer, block.timestamp, updatedAt, 1);
    }
}

contract PriceOracleTest is Test {
    PriceOracle oracle;
    MockFeed feed;

    address owner = makeAddr("owner");

    // $3 000.00 in 1e8 units
    int256 constant ETH_USD = 3_000_00000000;
    // $3.00/month in 1e8 units
    uint256 constant MONTHLY_USD = 3_00000000;
    // $15.00/year in 1e8 units
    uint256 constant ANNUAL_USD = 15_00000000;

    uint256 constant MAX_STALENESS = 1 hours;
    uint256 constant MONTH = 30 days;
    uint256 constant YEAR = 365 days;

    function setUp() public {
        feed = new MockFeed(ETH_USD);
        oracle = new PriceOracle(address(feed), MAX_STALENESS, MONTHLY_USD, ANNUAL_USD, owner);
    }

    // ---------------------------------------------------------------
    //                     MONTHLY PATH (duration < 1 year)
    // ---------------------------------------------------------------

    function test_price_one_month() public view {
        // $3 for 30 days at $3000/ETH = 3/3000 ETH = 1_000_000_000_000_000 wei (0.001 ETH)
        IPriceOracle.Price memory p = oracle.price("kyy", 0, MONTH);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (MONTHLY_USD * MONTH * 1e18) / (MONTH * uint256(ETH_USD));
        assertEq(p.base, expected);
        assertEq(p.premium, 0);
    }

    function test_price_three_months() public view {
        IPriceOracle.Price memory one = oracle.price("kyy", 0, MONTH);
        IPriceOracle.Price memory three = oracle.price("kyy", 0, MONTH * 3);
        assertEq(three.base, one.base * 3);
    }

    function test_price_monthly_is_linear_with_duration() public view {
        IPriceOracle.Price memory half = oracle.price("kyy", 0, MONTH / 2);
        IPriceOracle.Price memory full = oracle.price("kyy", 0, MONTH);
        assertEq(full.base, half.base * 2);
    }

    // ---------------------------------------------------------------
    //                     ANNUAL PATH (duration >= 1 year)
    // ---------------------------------------------------------------

    function test_price_one_year() public view {
        // $15/year at $3000/ETH = 15/3000 ETH = 5_000_000_000_000_000 wei (0.005 ETH)
        IPriceOracle.Price memory p = oracle.price("kyy", 0, YEAR);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (ANNUAL_USD * 1 * 1e18) / uint256(ETH_USD);
        assertEq(p.base, expected);
        assertEq(p.premium, 0);
    }

    function test_price_two_years() public view {
        IPriceOracle.Price memory one = oracle.price("kyy", 0, YEAR);
        IPriceOracle.Price memory two = oracle.price("kyy", 0, YEAR * 2);
        assertEq(two.base, one.base * 2);
    }

    function test_price_annual_cheaper_than_12_months() public view {
        // Annual ($15) must be cheaper than 12 × monthly ($3 × 12 = $36)
        IPriceOracle.Price memory annual = oracle.price("kyy", 0, YEAR);
        IPriceOracle.Price memory monthly12 = oracle.price("kyy", 0, MONTH * 12);
        assertLt(annual.base, monthly12.base);
    }

    function test_price_year_plus_one_month_remainder() public view {
        // 1 year + 30 days = annual rate for year + monthly rate for remainder
        IPriceOracle.Price memory pYearOnly = oracle.price("kyy", 0, YEAR);
        IPriceOracle.Price memory pMonthOnly = oracle.price("kyy", 0, MONTH);
        IPriceOracle.Price memory pYearAndMonth = oracle.price("kyy", 0, YEAR + MONTH);
        assertEq(pYearAndMonth.base, pYearOnly.base + pMonthOnly.base);
    }

    // ---------------------------------------------------------------
    //                         CROSS-TIER
    // ---------------------------------------------------------------

    function test_price_threshold_at_exactly_one_year() public view {
        // YEAR - 1 second → monthly path
        IPriceOracle.Price memory justUnder = oracle.price("kyy", 0, YEAR - 1);
        // YEAR → annual path
        IPriceOracle.Price memory exactYear = oracle.price("kyy", 0, YEAR);
        // Annual path must yield less wei than monthly path for same effective duration
        assertLt(exactYear.base, justUnder.base);
    }

    function test_price_higher_eth_price_means_less_wei_monthly() public {
        feed.setAnswer(ETH_USD * 2);
        IPriceOracle.Price memory p = oracle.price("kyy", 0, MONTH);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (MONTHLY_USD * MONTH * 1e18) / (MONTH * uint256(ETH_USD * 2));
        assertEq(p.base, expected);
    }

    function test_price_higher_eth_price_means_less_wei_annual() public {
        feed.setAnswer(ETH_USD * 2);
        IPriceOracle.Price memory p = oracle.price("kyy", 0, YEAR);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (ANNUAL_USD * 1 * 1e18) / uint256(ETH_USD * 2);
        assertEq(p.base, expected);
    }

    function test_price_long_name_same_as_short() public view {
        // Flat pricing: length doesn't matter above minimum
        IPriceOracle.Price memory short3 = oracle.price("kyy", 0, MONTH);
        IPriceOracle.Price memory long10 = oracle.price("averylongn", 0, MONTH);
        assertEq(short3.base, long10.base);
    }

    // ---------------------------------------------------------------
    //                         NAME LENGTH
    // ---------------------------------------------------------------

    function test_price_reverts_name_too_short_len_1() public {
        vm.expectRevert(abi.encodeWithSelector(IPriceOracle.NameTooShort.selector, uint256(1)));
        oracle.price("a", 0, MONTH);
    }

    function test_price_reverts_name_too_short_len_2() public {
        vm.expectRevert(abi.encodeWithSelector(IPriceOracle.NameTooShort.selector, uint256(2)));
        oracle.price("ab", 0, MONTH);
    }

    function test_price_accepts_min_length_3() public view {
        IPriceOracle.Price memory p = oracle.price("abc", 0, MONTH);
        assertGt(p.base, 0);
    }

    // ---------------------------------------------------------------
    //                         STALENESS
    // ---------------------------------------------------------------

    function test_ethUsdPrice_reverts_if_stale() public {
        vm.warp(1 days);
        uint256 staleUpdatedAt = block.timestamp - MAX_STALENESS - 1;
        feed.setUpdatedAt(staleUpdatedAt);
        vm.expectRevert(
            abi.encodeWithSelector(
                IPriceOracle.StalePriceFeed.selector,
                staleUpdatedAt,
                staleUpdatedAt + MAX_STALENESS
            )
        );
        oracle.ethUsdPrice();
    }

    function test_ethUsdPrice_accepts_exactly_at_staleness_boundary() public {
        vm.warp(1 days);
        feed.setUpdatedAt(block.timestamp - MAX_STALENESS);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(oracle.ethUsdPrice(), uint256(ETH_USD));
    }

    function test_price_reverts_if_stale_feed() public {
        vm.warp(1 days);
        feed.setUpdatedAt(block.timestamp - MAX_STALENESS - 1);
        vm.expectRevert();
        oracle.price("kyy", 0, MONTH);
    }

    function test_ethUsdPrice_reverts_if_zero_answer() public {
        feed.setAnswer(0);
        vm.expectRevert(abi.encodeWithSelector(IPriceOracle.InvalidPriceFeed.selector, int256(0)));
        oracle.ethUsdPrice();
    }

    function test_ethUsdPrice_reverts_if_negative_answer() public {
        feed.setAnswer(-1);
        vm.expectRevert(abi.encodeWithSelector(IPriceOracle.InvalidPriceFeed.selector, int256(-1)));
        oracle.ethUsdPrice();
    }

    // ---------------------------------------------------------------
    //                         PRICE FOR
    // ---------------------------------------------------------------

    function test_priceFor_returns_zero_for_short_names() public view {
        assertEq(oracle.priceFor(0), 0);
        assertEq(oracle.priceFor(1), 0);
        assertEq(oracle.priceFor(2), 0);
    }

    function test_priceFor_returns_annual_price_for_valid_lengths() public view {
        assertEq(oracle.priceFor(3), ANNUAL_USD);
        assertEq(oracle.priceFor(10), ANNUAL_USD);
        assertEq(oracle.priceFor(100), ANNUAL_USD);
    }

    // ---------------------------------------------------------------
    //                           ADMIN
    // ---------------------------------------------------------------

    function test_setPriceFeed() public {
        MockFeed newFeed = new MockFeed(ETH_USD * 2);
        vm.prank(owner);
        oracle.setPriceFeed(address(newFeed));
        assertEq(address(oracle.priceFeed()), address(newFeed));
    }

    function test_setPriceFeed_reverts_if_not_owner() public {
        vm.expectRevert();
        oracle.setPriceFeed(address(feed));
    }

    function test_setMaxStaleness() public {
        vm.prank(owner);
        oracle.setMaxStaleness(2 hours);
        assertEq(oracle.maxStaleness(), 2 hours);
    }

    function test_setMonthlyPrice() public {
        vm.prank(owner);
        oracle.setMonthlyPrice(5_00000000); // $5/month
        assertEq(oracle.monthlyPriceUsd(), 5_00000000);

        IPriceOracle.Price memory p = oracle.price("kyy", 0, MONTH);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (5_00000000 * MONTH * 1e18) / (MONTH * uint256(ETH_USD));
        assertEq(p.base, expected);
    }

    function test_setMonthlyPrice_reverts_if_not_owner() public {
        vm.expectRevert();
        oracle.setMonthlyPrice(5_00000000);
    }

    function test_setAnnualPrice() public {
        vm.prank(owner);
        oracle.setAnnualPrice(20_00000000); // $20/year
        assertEq(oracle.annualPriceUsd(), 20_00000000);

        IPriceOracle.Price memory p = oracle.price("kyy", 0, YEAR);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (20_00000000 * 1e18) / uint256(ETH_USD);
        assertEq(p.base, expected);
    }

    function test_setAnnualPrice_reverts_if_not_owner() public {
        vm.expectRevert();
        oracle.setAnnualPrice(20_00000000);
    }

    // ---------------------------------------------------------------
    //                        FUZZ TESTS
    // ---------------------------------------------------------------

    function testFuzz_monthly_price_scales_linearly(uint32 duration) public view {
        vm.assume(duration > 0 && duration < YEAR);
        IPriceOracle.Price memory p = oracle.price("kyy", 0, duration);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (MONTHLY_USD * duration * 1e18) / (MONTH * uint256(ETH_USD));
        assertEq(p.base, expected);
    }

    function testFuzz_annual_price_scales_linearly_with_years(uint8 numYears) public view {
        vm.assume(numYears > 0 && numYears <= 10);
        IPriceOracle.Price memory p = oracle.price("kyy", 0, YEAR * numYears);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (ANNUAL_USD * numYears * 1e18) / uint256(ETH_USD);
        assertEq(p.base, expected);
    }

    function testFuzz_price_scales_inversely_with_eth_price_monthly(uint80 ethPrice) public {
        vm.assume(ethPrice > 1e8 && ethPrice < 1_000_000e8);
        feed.setAnswer(int256(uint256(ethPrice)));
        IPriceOracle.Price memory p = oracle.price("kyy", 0, MONTH);
        uint256 expected = (MONTHLY_USD * 1e18) / uint256(ethPrice);
        assertEq(p.base, expected);
    }

    function testFuzz_price_scales_inversely_with_eth_price_annual(uint80 ethPrice) public {
        vm.assume(ethPrice > 1e8 && ethPrice < 1_000_000e8);
        feed.setAnswer(int256(uint256(ethPrice)));
        IPriceOracle.Price memory p = oracle.price("kyy", 0, YEAR);
        uint256 expected = (ANNUAL_USD * 1e18) / uint256(ethPrice);
        assertEq(p.base, expected);
    }
}
