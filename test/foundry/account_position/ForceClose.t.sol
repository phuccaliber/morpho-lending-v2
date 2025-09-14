// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../BaseLocal.t.sol";
import "../BaseMainnet.t.sol";
import "../common/Utils.t.sol";
import {ErrorLib} from "contracts/libraries/ErrorLib.sol";

contract ForceCloseTest is BaseMainnetTest, BaseLocalTest {
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
        // 1 BTC = 100_000 USDC
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

    function test_ForceCloseSuccess() public {
        bytes memory validatorSignature = _signForceClose(
            VALIDATOR_PRIVATE_KEY,
            APM,
            keccak256("0x01"),
            address(MORPHO_LIQUIDATOR)
        );

        vm.startPrank(LIQUIDATOR);
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_LIQUIDATOR),
            type(uint256).max
        );
        MORPHO_LIQUIDATOR.payment(
            APM,
            keccak256("0x01"),
            100_000e6,
            false,
            validatorSignature
        );

        Position memory position = MORPHO.position(
            Id.wrap(marketId),
            address(APM)
        );
        assertEq(position.borrowShares, 0, "Borrow should be 0");
        assertEq(position.collateral, 0, "Collateral should be 0");

        assertEq(
            IERC20(LOAN_TOKEN).balanceOf(address(MORPHO_MANAGEMENT)),
            40_000e6,
            "Borrower should have 40_000 USDC"
        );
    }

    function test_ForceCloseFailureWhenInvalidAmount() public {
        bytes memory validatorSignature = _signForceClose(
            VALIDATOR_PRIVATE_KEY,
            APM,
            keccak256("0x01"),
            address(MORPHO_LIQUIDATOR)
        );

        vm.startPrank(LIQUIDATOR);
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_LIQUIDATOR),
            type(uint256).max
        );
        vm.expectRevert();
        MORPHO_LIQUIDATOR.payment(
            address(APM),
            keccak256("0x01"),
            55_000e6,
            false,
            validatorSignature
        );
    }

    function test_ForceCloseFailureWhenInvalidValidator() public {
        bytes memory validatorSignature = _signForceClose(
            BORROWER_PRIVATE_KEY,
            APM,
            keccak256("0x01"),
            address(MORPHO_LIQUIDATOR)
        );

        vm.startPrank(LIQUIDATOR);
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_LIQUIDATOR),
            type(uint256).max
        );
        vm.expectRevert(
            abi.encodeWithSelector(ErrorLib.InvalidValidator.selector, BORROWER)
        );

        MORPHO_LIQUIDATOR.payment(
            address(APM),
            keccak256("0x01"),
            55_000e6,
            false,
            validatorSignature
        );
    }
}
