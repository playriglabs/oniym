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
    // $5.00/year in 1e8 units
    uint256 constant BASE_USD = 5_00000000;
    uint256 constant MAX_STALENESS = 1 hours;
    uint256 constant YEAR = 365 days;

    function setUp() public {
        feed = new MockFeed(ETH_USD);
        oracle = new PriceOracle(address(feed), MAX_STALENESS, BASE_USD, owner);
    }

    // ---------------------------------------------------------------
    //                        PRICE MATH
    // ---------------------------------------------------------------

    function test_price_one_year() public view {
        // $5/year at $3000/ETH = 5/3000 ETH = 1_666_666_666_666_666 wei (~0.00167 ETH)
        IPriceOracle.Price memory p = oracle.price("kyy", 0, YEAR);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (BASE_USD * YEAR * 1e18) / (YEAR * uint256(ETH_USD));
        assertEq(p.base, expected);
        assertEq(p.premium, 0);
    }

    function test_price_half_year() public view {
        IPriceOracle.Price memory full = oracle.price("kyy", 0, YEAR);
        IPriceOracle.Price memory half = oracle.price("kyy", 0, YEAR / 2);
        // Half duration → half price (linear)
        assertEq(half.base, full.base / 2);
    }

    function test_price_higher_eth_price_means_less_wei() public {
        // Double ETH price → half the wei cost
        feed.setAnswer(ETH_USD * 2);
        IPriceOracle.Price memory p = oracle.price("kyy", 0, YEAR);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (BASE_USD * YEAR * 1e18) / (YEAR * uint256(ETH_USD * 2));
        assertEq(p.base, expected);
    }

    function test_price_long_name_same_as_short() public view {
        // Flat pricing: length doesn't matter above minimum
        IPriceOracle.Price memory short3 = oracle.price("kyy", 0, YEAR);
        IPriceOracle.Price memory long10 = oracle.price("averylongn", 0, YEAR);
        assertEq(short3.base, long10.base);
    }

    function test_price_reverts_name_too_short_len_1() public {
        vm.expectRevert(abi.encodeWithSelector(IPriceOracle.NameTooShort.selector, uint256(1)));
        oracle.price("a", 0, YEAR);
    }

    function test_price_reverts_name_too_short_len_2() public {
        vm.expectRevert(abi.encodeWithSelector(IPriceOracle.NameTooShort.selector, uint256(2)));
        oracle.price("ab", 0, YEAR);
    }

    function test_price_accepts_min_length_3() public view {
        IPriceOracle.Price memory p = oracle.price("abc", 0, YEAR);
        assertGt(p.base, 0);
    }

    // ---------------------------------------------------------------
    //                         STALENESS
    // ---------------------------------------------------------------

    function test_ethUsdPrice_reverts_if_stale() public {
        vm.warp(1 days); // ensure block.timestamp > MAX_STALENESS
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
        // updatedAt + maxStaleness == block.timestamp → not yet stale (strict >)
        feed.setUpdatedAt(block.timestamp - MAX_STALENESS);
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(oracle.ethUsdPrice(), uint256(ETH_USD));
    }

    function test_price_reverts_if_stale_feed() public {
        vm.warp(1 days);
        feed.setUpdatedAt(block.timestamp - MAX_STALENESS - 1);
        vm.expectRevert();
        oracle.price("kyy", 0, YEAR);
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

    function test_priceFor_returns_base_for_valid_lengths() public view {
        assertEq(oracle.priceFor(3), BASE_USD);
        assertEq(oracle.priceFor(10), BASE_USD);
        assertEq(oracle.priceFor(100), BASE_USD);
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

    function test_setBasePriceUsd() public {
        vm.prank(owner);
        oracle.setBasePriceUsd(10_00000000); // $10/year
        assertEq(oracle.basePriceUsd(), 10_00000000);

        // New price should be double the old
        IPriceOracle.Price memory p = oracle.price("kyy", 0, YEAR);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (10_00000000 * YEAR * 1e18) / (YEAR * uint256(ETH_USD));
        assertEq(p.base, expected);
    }

    // ---------------------------------------------------------------
    //                        FUZZ TESTS
    // ---------------------------------------------------------------

    function testFuzz_price_scales_linearly_with_duration(uint32 duration) public view {
        vm.assume(duration > 0 && duration <= 10 * YEAR);
        IPriceOracle.Price memory p = oracle.price("kyy", 0, duration);
        // base is proportional to duration
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 expected = (BASE_USD * duration * 1e18) / (YEAR * uint256(ETH_USD));
        assertEq(p.base, expected);
    }

    function testFuzz_price_scales_inversely_with_eth_price(uint80 ethPrice) public {
        vm.assume(ethPrice > 1e8 && ethPrice < 1_000_000e8); // $1 to $1M ETH
        feed.setAnswer(int256(uint256(ethPrice)));
        IPriceOracle.Price memory p = oracle.price("kyy", 0, YEAR);
        uint256 expected = (BASE_USD * 1e18) / uint256(ethPrice);
        assertEq(p.base, expected);
    }
}
