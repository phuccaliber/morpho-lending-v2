// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/MarketParamsLib.sol";

import "../BaseMainnet.t.sol";
import "../BaseLocal.t.sol";
import "../common/Utils.t.sol";
import {ErrorLib} from "contracts/libraries/ErrorLib.sol";

contract SupplyCollateralTest is BaseMainnetTest, BaseLocalTest, Utils {
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

    function test_createAPMSuccess(address apm, address authorizer) public {
        vm.assume(apm != address(0));
        vm.assume(authorizer != address(0));

        MORPHO_MANAGEMENT.createAPM(apm, authorizer, VALIDATOR);

        assertEq(MORPHO_MANAGEMENT.apmValidators(apm), VALIDATOR);
        assertEq(MORPHO_MANAGEMENT.apmAuthorizers(apm), authorizer);
    }

    function test_createAPMFailureApmCreatedBefore(
        address apm,
        address authorizer
    ) public {
        vm.assume(apm != address(0));
        vm.assume(authorizer != address(0));

        MORPHO_MANAGEMENT.createAPM(apm, authorizer, VALIDATOR);

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidAPM.selector));
        MORPHO_MANAGEMENT.createAPM(apm, authorizer, VALIDATOR);
    }
}
