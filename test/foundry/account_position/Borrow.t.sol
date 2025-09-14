// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../BaseLocal.t.sol";
import "../BaseMainnet.t.sol";
import "../common/Utils.t.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {ErrorsLib} from "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/ErrorsLib.sol";
import {ErrorLib} from "contracts/libraries/ErrorLib.sol";

contract BorrowTest is BaseMainnetTest, BaseLocalTest {
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

    function test_BorrowSuccess() public {
        uint256 assets = 50000e6;
        // Borrow 50_000 USDC
        (,uint96 authorizerNonce) = MORPHO_MANAGEMENT.marketAccess(APM);

        vm.prank(AUTHORIZER);
        bytes memory signature = _signBorrow(
            AUTHORIZER_PRIVATE_KEY,
            APM,
            assets,
            BORROWER,
            authorizerNonce,
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

        Position memory position = MORPHO.position(
            Id.wrap(marketId),
            address(APM)
        );
        assertGt(position.borrowShares, 0, "Borrow should be greater than 0");
        Market memory market = MORPHO.market(Id.wrap(marketId));
        assertEq(
            market.totalBorrowAssets,
            assets,
            "Borrow should be 50_000 USDC"
        );
        assertEq(
            market.totalBorrowShares,
            position.borrowShares,
            "BORROWER should borrow all shares"
        );
        
        (, uint96 counter) = MORPHO_MANAGEMENT.marketAccess(APM);

        assertEq(
            counter,
            1,
            "Nonces should be 1"
        );
        assertEq(
            IERC20(LOAN_TOKEN).balanceOf(BORROWER),
            assets,
            "BORROWER should receive 50_000 USDC"
        );
    }

    function test_BorrowFailureOverCollateral() public {
        uint256 assets = 110_000e6;
        // Borrow 50_000 USDC
        (, uint96 authorizerNonce) = MORPHO_MANAGEMENT.marketAccess(APM);

        vm.prank(AUTHORIZER);
        bytes memory signature = _signBorrow(
            AUTHORIZER_PRIVATE_KEY,
            APM,
            assets,
            BORROWER,
            authorizerNonce,
            block.timestamp + 1000,
            address(MORPHO_MANAGEMENT)
        );
        vm.expectRevert(bytes(ErrorsLib.INSUFFICIENT_COLLATERAL));
        MORPHO_MANAGEMENT.borrow(
            APM,
            assets,
            BORROWER,
            block.timestamp + 1000,
            marketParams,
            signature
        );
    }

    // function test_BorrowFailureUsingDeprecatedSignature() public {
    //     uint256 assets = 50000e6;
    //     // Borrow 50_000 USDC
    //     uint256 authorizerNonce = BORROWER_APM.actionCounters(POSITION_ID);

    //     vm.prank(BORROWER);
    //     bytes memory signature = _signBorrow(
    //         AUTHORIZER_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         assets,
    //         BORROWER,
    //         authorizerNonce,
    //         block.timestamp + 1000
    //     );
    //     BORROWER_APM.borrow(
    //         POSITION_ID,
    //         assets,
    //         BORROWER,
    //         block.timestamp + 1000,
    //         marketParams,
    //         signature
    //     );

    //     vm.expectRevert(
    //         abi.encodeWithSelector(ErrorLib.InvalidAuthorizerSig.selector)
    //     );
    //     BORROWER_APM.borrow(
    //         POSITION_ID,
    //         assets,
    //         BORROWER,
    //         block.timestamp + 1000,
    //         marketParams,
    //         signature
    //     );
    // }

    function test_BorrowFailureNotAuthorizer() public {
        uint256 assets = 50000e6;
        // Borrow 50_000 USDC
        (,uint96 authorizerNonce) = MORPHO_MANAGEMENT.marketAccess(APM);

        vm.prank(AUTHORIZER);
        uint256 AUTHORIZER2_PK = uint256(keccak256("AUTHORIZER_2"));
        address AUTHORIZER2 = vm.addr(AUTHORIZER2_PK);
        bytes memory signature = _signBorrow(
            AUTHORIZER2_PK,
            APM,
            assets,
            AUTHORIZER2,
            authorizerNonce,
            block.timestamp + 1000,
            address(MORPHO_MANAGEMENT)
        );
        vm.expectRevert(
            abi.encodeWithSelector(ErrorLib.InvalidAuthorizerSig.selector)
        );
        MORPHO_MANAGEMENT.borrow(
            APM,
            assets,
            AUTHORIZER2,
            block.timestamp + 1000,
            marketParams,
            signature
        );
    }
}
