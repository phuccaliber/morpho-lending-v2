// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/MarketParamsLib.sol";

import "../BaseMainnet.t.sol";
import "../BaseLocal.t.sol";
import "../common/Utils.t.sol";
import {ErrorLib} from "contracts/libraries/ErrorLib.sol";

contract CreateAPMTest is BaseMainnetTest, BaseLocalTest {
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

    function test_createAPMSuccess(uint256 apmKey, address authorizer) public {
        vm.assume(authorizer != address(0));
        vm.assume(apmKey != 0);

        uint256 privateKey = uint256(keccak256(abi.encodePacked(apmKey)));
        address apm = vm.addr(privateKey);
        uint256 deadline = block.timestamp + 1 hours;
        Authorization memory authorization = Authorization({
            authorizer: apm,
            authorized: address(MORPHO_MANAGEMENT),
            isAuthorized: true,
            nonce: 0,
            deadline: deadline
        });
        bytes memory signature = _signMorphoSetAuthorizer(
            privateKey,
            authorization,
            address(MORPHO)
        );
        bytes memory walletDelegatorSig = _signAPMGenerated(
            DELEGATOR_PRIVATE_KEY,
            apm,
            deadline,
            address(MORPHO_MANAGEMENT)
        );
        MORPHO_MANAGEMENT.createAPM(
            apm,
            authorizer,
            VALIDATOR,
            deadline,
            signature,
            walletDelegatorSig
        );

        assertEq(MORPHO_MANAGEMENT.apmValidators(apm), VALIDATOR);
        (address _authorizer, ) = MORPHO_MANAGEMENT.marketAccess(apm);
        assertEq(_authorizer, authorizer);
        assertEq(MORPHO.isAuthorized(apm, address(MORPHO_MANAGEMENT)), true);
    }

    function test_createAPMFailureInvalidDelegatorSig(
        uint256 apmKey,
        address authorizer
    ) public {
        vm.assume(apmKey != 0);
        vm.assume(authorizer != address(0));

        uint256 privateKey = uint256(keccak256(abi.encodePacked(apmKey)));
        address apm = vm.addr(privateKey);
        uint256 deadline = block.timestamp + 1 hours;
        Authorization memory authorization = Authorization({
            authorizer: apm,
            authorized: address(MORPHO_MANAGEMENT),
            isAuthorized: true,
            nonce: 0,
            deadline: deadline
        });
        bytes memory signature = _signMorphoSetAuthorizer(
            privateKey,
            authorization,
            address(MORPHO)
        );
        bytes memory walletDelegatorSig = _signAPMGenerated(
            privateKey,
            apm,
            deadline,
            address(MORPHO_MANAGEMENT)
        );
        vm.expectRevert(
            abi.encodeWithSelector(ErrorLib.InvalidDelegator.selector, apm)
        );
        MORPHO_MANAGEMENT.createAPM(
            apm,
            authorizer,
            VALIDATOR,
            deadline,
            signature,
            walletDelegatorSig
        );
    }

    function test_createAPMFailureApmCreatedBefore(
        uint256 apmKey,
        address authorizer
    ) public {
        vm.assume(apmKey != 0);
        vm.assume(authorizer != address(0));

        uint256 privateKey = uint256(keccak256(abi.encodePacked(apmKey)));
        address apm = vm.addr(privateKey);
        uint256 deadline = block.timestamp + 1 hours;
        Authorization memory authorization = Authorization({
            authorizer: apm,
            authorized: address(MORPHO_MANAGEMENT),
            isAuthorized: true,
            nonce: 0,
            deadline: deadline
        });
        bytes memory signature = _signMorphoSetAuthorizer(
            privateKey,
            authorization,
            address(MORPHO)
        );
        bytes memory walletDelegatorSig = _signAPMGenerated(
            DELEGATOR_PRIVATE_KEY,
            apm,
            deadline,
            address(MORPHO_MANAGEMENT)
        );
        MORPHO_MANAGEMENT.createAPM(
            apm,
            authorizer,
            VALIDATOR,
            deadline,
            signature,
            walletDelegatorSig
        );

        vm.expectRevert(abi.encodeWithSelector(ErrorLib.InvalidAPM.selector));
        MORPHO_MANAGEMENT.createAPM(
            apm,
            authorizer,
            VALIDATOR,
            block.timestamp + 1 hours,
            "",
            ""
        );
    }
}
