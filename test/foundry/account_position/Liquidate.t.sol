// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../BaseMainnet.t.sol";
import "../BaseLocal.t.sol";
import "../common/Utils.t.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/ErrorsLib.sol";
import "contracts/libraries/ErrorLib.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/MarketParamsLib.sol";

contract LiquidateTest is BaseMainnetTest, BaseLocalTest {
    function setUp() public override(BaseMainnetTest, BaseLocalTest) {
        string memory profile = vm.envString("PROFILE");
        if (keccak256(bytes(profile)) == keccak256(bytes("mainnet"))) {
            BaseMainnetTest.setUp();
        } else if (keccak256(bytes(profile)) == keccak256(bytes("local"))) {
            BaseLocalTest.setUp();
        } else {
            revert("Invalid profile");
        }
        vm.startPrank(VALIDATOR);

        uint256 amount = 1e8;

        bytes memory supplySig = _signSupply(
            AUTHORIZER_PRIVATE_KEY,
            APM,
            marketId,
            amount,
            0,
            address(MORPHO_MANAGEMENT)
        );

        bytes memory validatorSig = _signValidatorSupply(
            VALIDATOR_PRIVATE_KEY,
            supplySig,
            address(MORPHO_SUPPLIER)
        );
        MORPHO_SUPPLIER.supply(
            APM,
            AUTHORIZER,
            amount,
            marketParams,
            supplySig,
            validatorSig
        );
        vm.stopPrank();

        vm.startPrank(AUTHORIZER);
        // Borrow 60_000 USDC
        uint256 assets = 60_000e6;

        bytes memory signature = _signBorrow(
            AUTHORIZER_PRIVATE_KEY,
            APM,
            assets,
            BORROWER,
            0,
            block.timestamp + 1000,
            address(MORPHO_MANAGEMENT)
        );
        MORPHO_MANAGEMENT.borrow(
            APM,
            assets,
            BORROWER,
            block.timestamp + 1000,
            marketParams,
            signature
        );
        vm.stopPrank();
    }

    function test_LiquidateSuccess() public {
        _setOraclePrice(65000e34);

        vm.startPrank(LIQUIDATOR);
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_LIQUIDATOR),
            type(uint256).max
        );
        MORPHO_LIQUIDATOR.payment(
            APM,
            keccak256("0x01"),
            65000e6,
            true,
            ""
        );

        Position memory position = MORPHO.position(
            Id.wrap(marketId),
            address(APM)
        );
        assertEq(position.borrowShares, 0, "Borrow should be 0");
        assertEq(position.collateral, 0, "Collateral should be 0");

        assertGt(
            IERC20(LOAN_TOKEN).balanceOf(address(MORPHO_MANAGEMENT)),
            0,
            "Borrower should have USDC"
        );
        address pFeeAddress = MORPHO_MANAGEMENT.getPFeeAddress();
        assertGt(
            IERC20(LOAN_TOKEN).balanceOf(pFeeAddress),
            0,
            "Protocol fee should have USDC"
        );
    }

    function test_LiquidateBadDebtSuccess() public {
        _setOraclePrice(55000e34);

        vm.startPrank(LIQUIDATOR);
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_LIQUIDATOR),
            type(uint256).max
        );
        MORPHO_LIQUIDATOR.payment(
            APM,
            keccak256("0x01"),
            55_000e6,
            true,
            ""
        );

        Position memory position = MORPHO.position(
            Id.wrap(marketId),
            address(APM)
        );
        assertEq(position.borrowShares, 0, "Borrow should be 0");
        assertEq(position.collateral, 0, "Collateral should be 0");

        assertEq(
            IERC20(LOAN_TOKEN).balanceOf(address(MORPHO_MANAGEMENT)),
            0,
            "Borrower should not have USDC"
        );
        address pFeeAddress = MORPHO_MANAGEMENT.getPFeeAddress();
        assertGt(
            IERC20(LOAN_TOKEN).balanceOf(pFeeAddress),
            0,
            "Protocol fee should have USDC"
        );
    }

    function test_LiquidateFailureWhenHealthy() public {
        vm.startPrank(LIQUIDATOR);
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_LIQUIDATOR),
            type(uint256).max
        );
        vm.expectRevert(bytes(ErrorsLib.HEALTHY_POSITION));
        MORPHO_LIQUIDATOR.payment(
            APM,
            keccak256("0x01"),
            55_000e6,
            true,
            ""
        );
    }

    function test_LiquidateSuccessWhenCoverDebtButNotEnoughSurplus() public {
        _setOraclePrice(65000e34);

        vm.startPrank(LIQUIDATOR);
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_LIQUIDATOR),
            type(uint256).max
        );
        vm.expectEmit(true, true, true, false);
        emit IMorphoManagement.ForceClosed(
            address(MORPHO_LIQUIDATOR),
            address(APM),
            marketId,
            0,
            0
        );
        vm.expectEmit(true, true, true, true);
        emit IOptimexCollateralToken.TokenDeallocated(
            address(MORPHO_LIQUIDATOR),
            address(MORPHO_LIQUIDATOR),
            1e8
        );
        MORPHO_LIQUIDATOR.payment(
            APM,
            keccak256("0x01"),
            61000e6,
            true,
            ""
        );

        uint256 apmBalance = IERC20(LOAN_TOKEN).balanceOf(
            address(MORPHO_MANAGEMENT)
        );
        assertEq(apmBalance, 1000e6);
    }

    function test_LiquidateFailureWhenPayNotEnoughUserBorrow() public {
        _setOraclePrice(65000e34);

        vm.startPrank(LIQUIDATOR);
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_LIQUIDATOR),
            type(uint256).max
        );
        vm.expectRevert();
        MORPHO_LIQUIDATOR.payment(
            APM,
            keccak256("0x01"),
            50000e6,
            true,
            ""
        );
    }
}
