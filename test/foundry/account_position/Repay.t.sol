// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../BaseLocal.t.sol";
import "../BaseMainnet.t.sol";
import "../common/Utils.t.sol";
import {stdError} from "forge-std/StdError.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/MarketParamsLib.sol";

contract RepayTest is BaseMainnetTest, BaseLocalTest {
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

        // Borrow 50_000 USDC
        uint256 borrowAssets = 50000e6;
        vm.prank(AUTHORIZER);
        bytes memory signature = _signBorrow(
            AUTHORIZER_PRIVATE_KEY,
            APM,
            borrowAssets,
            BORROWER,
            0,
            block.timestamp + 1000,
            address(MORPHO_MANAGEMENT)
        );
        MORPHO_MANAGEMENT.borrow(
            APM,
            borrowAssets,
            BORROWER,
            block.timestamp + 1000,
            marketParams,
            signature
        );
        vm.stopPrank();
    }

    function test_RepaySuccess() public {
        uint256 repayAssets = 20000e6;
        vm.startPrank(BORROWER);
        uint256 loanBorrowerBalanceBefore = IERC20(LOAN_TOKEN).balanceOf(
            BORROWER
        );
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_MANAGEMENT),
            type(uint256).max
        );
        MORPHO_MANAGEMENT.repay(APM, repayAssets, 0, marketParams);
        uint256 loanBorrowerBalanceAfter = IERC20(LOAN_TOKEN).balanceOf(
            BORROWER
        );
        assertEq(
            loanBorrowerBalanceAfter,
            loanBorrowerBalanceBefore - repayAssets,
            "Borrower should have less USDC"
        );
        vm.stopPrank();
    }

    function test_RepayFullAmountSuccess() public {
        // Borrow 50_000 USDC

        Position memory position = MORPHO.position(
            Id.wrap(marketId),
            address(APM)
        );
        vm.startPrank(BORROWER);
        uint256 loanBorrowerBalanceBefore = IERC20(LOAN_TOKEN).balanceOf(
            BORROWER
        );
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_MANAGEMENT),
            type(uint256).max
        );
        MORPHO_MANAGEMENT.repay(APM, 0, position.borrowShares, marketParams);
        uint256 loanBorrowerBalanceAfter = IERC20(LOAN_TOKEN).balanceOf(
            BORROWER
        );
        assertEq(
            loanBorrowerBalanceAfter,
            loanBorrowerBalanceBefore - 50000e6,
            "Borrower should have same USDC"
        );
        Position memory positionAfter = MORPHO.position(
            Id.wrap(marketId),
            address(APM)
        );
        assertEq(
            positionAfter.borrowShares,
            0,
            "Borrower should have no borrow shares"
        );
        vm.stopPrank();
    }

    function test_RepayFailureWhenOutOfBorrowedAmount() public {
        // Borrow 50_000 USDC

        vm.startPrank(BORROWER);
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_MANAGEMENT),
            type(uint256).max
        );
        vm.expectRevert(stdError.arithmeticError);
        MORPHO_MANAGEMENT.repay(APM, 50000e6 + 1e6, 0, marketParams);
        vm.stopPrank();
    }

    function test_RepayFailureWhenNotEnoughAssetsToRepay() public {
        // Borrow 50_000 USDC

        address REPAYER2 = makeAddr("REPAYER2");
        vm.startPrank(REPAYER2);
        IERC20(LOAN_TOKEN).approve(
            address(MORPHO_MANAGEMENT),
            type(uint256).max
        );
        vm.expectRevert();
        MORPHO_MANAGEMENT.repay(APM, 10000e6, 0, marketParams);
        vm.stopPrank();
    }
}
