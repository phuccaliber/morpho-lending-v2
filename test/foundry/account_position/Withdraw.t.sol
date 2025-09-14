// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../BaseMainnet.t.sol";
import "../BaseLocal.t.sol";
import "../common/Utils.t.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {ErrorLib} from "contracts/libraries/ErrorLib.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/MarketParamsLib.sol";

contract WithdrawTest is BaseMainnetTest, BaseLocalTest {
    using MarketParamsLib for MarketParams;

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
    }

    function test_WithdrawCollateralSuccess() public {
        uint256 assets = 1e8;
        // Borrow 50_000 USDC
        uint256 balanceBefore = BTC.balanceOf(address(BTC));
        vm.prank(AUTHORIZER);
        uint256 deadline = block.timestamp + 1000;
        (, uint96 authorizerNonce) = MORPHO_MANAGEMENT.marketAccess(APM);
        bytes memory signature = _signWithdraw(
            AUTHORIZER_PRIVATE_KEY,
            APM,
            assets,
            authorizerNonce,
            deadline,
            address(MORPHO_MANAGEMENT)
        );
        MORPHO_MANAGEMENT.withdraw(
            APM,
            assets,
            deadline,
            marketParams,
            signature
        );
        assertEq(
            BTC.balanceOf(address(BTC)),
            balanceBefore + 1e8,
            "oBTC balance should increase by 1e8"
        );
        (, uint96 authorizerNonce2) = MORPHO_MANAGEMENT.marketAccess(APM);
        assertEq(
            authorizerNonce2,
            authorizerNonce + 1,
            "Authorizer nonce should be incremented"
        );
        Position memory position = MORPHO.position(Id.wrap(marketId), APM);
        assertEq(position.collateral, 0, "Collateral should be 0");
    }

    function test_WithdrawCollateralFailureNotAuthorizedUser() public {
        uint256 assets = 1e8;
        vm.prank(BORROWER);
        uint256 deadline = block.timestamp + 1000;
        (, uint96 authorizerNonce) = MORPHO_MANAGEMENT.marketAccess(APM);
        bytes memory signature = _signWithdraw(
            BORROWER_PRIVATE_KEY,
            APM,
            assets,
            authorizerNonce,
            deadline,
            address(MORPHO_MANAGEMENT)
        );
        vm.expectRevert(
            abi.encodeWithSelector(ErrorLib.InvalidAuthorizerSig.selector)
        );
        MORPHO_MANAGEMENT.withdraw(
            APM,
            assets,
            deadline,
            marketParams,
            signature
        );
    }

    function test_WithdrawCollateralFailureWithdrawPartially() public {
        uint256 assets = 1e8 - 1;
        vm.prank(BORROWER);
        uint256 deadline = block.timestamp + 1000;
        (, uint96 authorizerNonce) = MORPHO_MANAGEMENT.marketAccess(APM);
        bytes memory signature = _signWithdraw(
            AUTHORIZER_PRIVATE_KEY,
            APM,
            assets,
            authorizerNonce,
            deadline,
            address(MORPHO_MANAGEMENT)
        );
        vm.expectRevert(
            abi.encodeWithSelector(ErrorLib.InvalidAmount.selector)
        );
        MORPHO_MANAGEMENT.withdraw(
            APM,
            assets,
            deadline,
            marketParams,
            signature
        );
    }

    function test_WithdrawCollateralFailureWithdrawOverAmount() public {
        uint256 assets = 1e8 + 1;
        vm.prank(BORROWER);
        uint256 deadline = block.timestamp + 1000;
        (, uint96 authorizerNonce) = MORPHO_MANAGEMENT.marketAccess(APM);
        bytes memory signature = _signWithdraw(
            AUTHORIZER_PRIVATE_KEY,
            APM,
            assets,
            authorizerNonce,
            deadline,
            address(MORPHO_MANAGEMENT)
        );
        vm.expectRevert(
            abi.encodeWithSelector(ErrorLib.InvalidAmount.selector)
        );
        MORPHO_MANAGEMENT.withdraw(
            APM,
            assets,
            deadline,
            marketParams,
            signature
        );
    }
}
