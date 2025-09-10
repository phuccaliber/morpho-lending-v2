// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/MarketParamsLib.sol";

import "../BaseMainnet.t.sol";
import "../BaseLocal.t.sol";
import "../common/Utils.t.sol";
import {ErrorLib} from "contracts/libraries/ErrorLib.sol";

contract SupplyCollateralTest is BaseMainnetTest, BaseLocalTest {
    function setUp() public override(BaseMainnetTest, BaseLocalTest) {
        string memory profile = vm.envString("PROFILE");
        if (keccak256(bytes(profile)) == keccak256(bytes("mainnet"))) {
            BaseMainnetTest.setUp();
        } else if (keccak256(bytes(profile)) == keccak256(bytes("local"))) {
            BaseLocalTest.setUp();
        } else {
            revert("Invalid profile");
        }
    }

    using MarketParamsLib for MarketParams;

    function test_SupplyCollateralSuccess() public {
        vm.startPrank(VALIDATOR);
        // 1 BTC
        uint256 amount = 1e8;

        uint256 currentNonce = MORPHO_MANAGEMENT.loanCounters(APM);

        bytes memory supplySig = _signSupply(
            AUTHORIZER_PRIVATE_KEY,
            APM,
            marketId,
            amount,
            currentNonce,
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
        Position memory position = MORPHO.position(
            Id.wrap(marketId),
            address(APM)
        );
        assertEq(position.collateral, amount, "Collateral should be 1 BTC");
        address authorizer = MORPHO_MANAGEMENT.apmAuthorizers(APM);
        uint256 loanIndex = MORPHO_MANAGEMENT.loanCounters(APM);
        assertEq(MORPHO_MANAGEMENT.apmMarkets(APM), marketId, "Market should be set");
        assertEq(authorizer, AUTHORIZER, "Authorizer should be set");
        assertEq(loanIndex, 1, "Loan nonce should be 1");
    }

    function test_SupplyCollateralFailureMarketMismatch() public {
        vm.startPrank(VALIDATOR);
        // 1 BTC
        uint256 amount = 1e8;

        uint256 currentNonce = MORPHO_MANAGEMENT.loanCounters(APM);

        bytes memory supplySig = _signSupply(
            AUTHORIZER_PRIVATE_KEY,
            APM,
            marketId,
            amount,
            currentNonce,
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

        currentNonce = MORPHO_MANAGEMENT.loanCounters(APM);
        marketParams.oracle = makeAddr("ORACLE");
        validatorSig = _signValidatorSupply(
            VALIDATOR_PRIVATE_KEY,
            "",
            address(MORPHO_SUPPLIER)
        );
        vm.expectRevert(abi.encodeWithSelector(ErrorLib.MarketMismatch.selector, marketId, Id.unwrap(marketParams.id())));
        MORPHO_SUPPLIER.supply(
            APM,
            AUTHORIZER,
            amount,
            marketParams,
            "",
            validatorSig
        );


    }

    // function test_SupplyCollateralSuccess() public {
    //     vm.startPrank(VALIDATOR);
    //     // 1 BTC
    //     uint256 amount = 1e8;

    //     uint256 currentNonce = BORROWER_APM.loanCounters(POSITION_ID);

    //     bytes memory setAuthorizerSig = _signSetAuthorizer(
    //         BORROWER_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         marketId,
    //         AUTHORIZER
    //     );

    //     bytes memory supplySig = _signSupply(
    //         AUTHORIZER_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         marketId,
    //         amount,
    //         currentNonce
    //     );

    //     bytes memory validatorSig = _signValidatorSupply(
    //         VALIDATOR_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         setAuthorizerSig,
    //         supplySig,
    //         address(MORPHO_SUPPLIER)
    //     );
    //     MORPHO_SUPPLIER.supply(
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         AUTHORIZER,
    //         amount,
    //         marketParams,
    //         setAuthorizerSig,
    //         supplySig,
    //         validatorSig
    //     );
    //     Position memory position = MORPHO.position(
    //         Id.wrap(marketId),
    //         address(BORROWER_APM)
    //     );
    //     assertEq(position.collateral, amount, "Collateral should be 1 BTC");
    //     (, address authorizer) = BORROWER_APM.marketAccess(POSITION_ID);
    //     uint256 loanIndex = BORROWER_APM.loanCounters(POSITION_ID);
    //     assertEq(authorizer, AUTHORIZER, "Authorizer should be set");
    //     assertEq(loanIndex, 1, "Loan nonce should be 1");

    //     bytes memory supplySig2 = _signSupply(
    //         AUTHORIZER_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         marketId,
    //         amount,
    //         1
    //     );
    //     bytes memory validatorSig2 = _signValidatorSupply(
    //         VALIDATOR_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         "",
    //         supplySig2,
    //         address(MORPHO_SUPPLIER)
    //     );
    //     MORPHO_SUPPLIER.supply(
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         AUTHORIZER,
    //         amount,
    //         marketParams,
    //         "",
    //         supplySig2,
    //         validatorSig2
    //     );
    //     (, address authorizer2) = BORROWER_APM.marketAccess(POSITION_ID);
    //     uint256 loanIndex2 = BORROWER_APM.loanCounters(POSITION_ID);
    //     assertEq(authorizer2, AUTHORIZER, "Authorizer should be set");
    //     assertEq(loanIndex2, 2, "Loan nonce should be 2");
    //     Position memory position2 = MORPHO.position(
    //         Id.wrap(marketId),
    //         address(BORROWER_APM)
    //     );
    //     assertEq(
    //         position2.collateral,
    //         amount * 2,
    //         "Collateral should be 2 BTC"
    //     );
    //     vm.stopPrank();
    // }

    // function test_SupplyCollateralFailureNotValidator() public {
    //     vm.startPrank(VALIDATOR);
    //     // 1 BTC
    //     uint256 amount = 1e8;

    //     uint256 currentNonce = BORROWER_APM.loanCounters(POSITION_ID);

    //     bytes memory setAuthorizerSig = _signSetAuthorizer(
    //         BORROWER_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         marketId,
    //         AUTHORIZER
    //     );

    //     bytes memory supplySig = _signSupply(
    //         AUTHORIZER_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         marketId,
    //         amount,
    //         currentNonce
    //     );

    //     uint256 VALIDATOR_FAKE_PK = uint256(keccak256("VALIDATOR_FAKE"));
    //     address VALIDATOR_FAKE = vm.addr(VALIDATOR_FAKE_PK);

    //     bytes memory validatorSig = _signValidatorSupply(
    //         VALIDATOR_FAKE_PK,
    //         address(BORROWER_APM),
    //         setAuthorizerSig,
    //         supplySig,
    //         address(MORPHO_SUPPLIER)
    //     );
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             ErrorLib.InvalidValidator.selector,
    //             VALIDATOR_FAKE
    //         )
    //     );
    //     MORPHO_SUPPLIER.supply(
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         AUTHORIZER,
    //         amount,
    //         marketParams,
    //         setAuthorizerSig,
    //         supplySig,
    //         validatorSig
    //     );
    // }

    // function test_SupplyCollateralFailureReuseDeprecatedUserSignature() public {
    //     vm.startPrank(VALIDATOR);
    //     // 1 BTC
    //     uint256 amount = 1e8;

    //     uint256 currentNonce = BORROWER_APM.loanCounters(POSITION_ID);

    //     bytes memory setAuthorizerSig = _signSetAuthorizer(
    //         BORROWER_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         marketId,
    //         AUTHORIZER
    //     );

    //     bytes memory supplySig = _signSupply(
    //         AUTHORIZER_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         marketId,
    //         amount,
    //         currentNonce
    //     );

    //     bytes memory validatorSig = _signValidatorSupply(
    //         VALIDATOR_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         setAuthorizerSig,
    //         supplySig,
    //         address(MORPHO_SUPPLIER)
    //     );
    //     MORPHO_SUPPLIER.supply(
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         AUTHORIZER,
    //         amount,
    //         marketParams,
    //         setAuthorizerSig,
    //         supplySig,
    //         validatorSig
    //     );

    //     bytes memory validatorSig2 = _signValidatorSupply(
    //         VALIDATOR_PRIVATE_KEY,
    //         address(BORROWER_APM),
    //         "",
    //         supplySig,
    //         address(MORPHO_SUPPLIER)
    //     );
    //     vm.expectRevert(
    //         abi.encodeWithSelector(ErrorLib.InvalidAuthorizerSig.selector)
    //     );
    //     MORPHO_SUPPLIER.supply(
    //         address(BORROWER_APM),
    //         POSITION_ID,
    //         AUTHORIZER,
    //         amount,
    //         marketParams,
    //         "",
    //         supplySig,
    //         validatorSig2
    //     );
    //     vm.stopPrank();
    // }

    // function test_SupplyCollateralFailurePositionManagerNotExists() public {
    //     vm.startPrank(VALIDATOR);
    //     // 1 BTC
    //     uint256 amount = 1e8;

    //     // Get the current nonce from the APM contract
    //     address BORROWER_APM_FAKE = makeAddr("BORROWER_APM");

    //     bytes memory setAuthorizerSig = "dummy_signature";

    //     bytes memory supplySig = "dummy_signature";

    //     bytes memory validatorSig = _signValidatorSupply(
    //         VALIDATOR_PRIVATE_KEY,
    //         BORROWER_APM_FAKE,
    //         setAuthorizerSig,
    //         supplySig,
    //         address(MORPHO_SUPPLIER)
    //     );
    //     vm.expectRevert();
    //     MORPHO_SUPPLIER.supply(
    //         address(BORROWER_APM_FAKE),
    //         POSITION_ID,
    //         AUTHORIZER,
    //         amount,
    //         marketParams,
    //         setAuthorizerSig,
    //         supplySig,
    //         validatorSig
    //     );
    //     vm.stopPrank();
    // }
}
