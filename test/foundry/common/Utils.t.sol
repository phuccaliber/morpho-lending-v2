/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import "@morpho-blue/interfaces/IMorpho.sol";

contract Utils is Test {
    bytes32 private constant _SET_AUTHORIZER_TYPEHASH =
        0x8ffe98054fd6401af07e7471e50e6a855a3edb1246ede4d5d35e79a29167a7e8;

    bytes32 private constant _SUPPLY_TYPEHASH =
        keccak256(
            "SupplyCollateral(address apm,bytes32 marketId,uint256 assets,uint256 nonce)"
        );

    bytes32 private constant _VALIDATOR_SUPPLY_TYPEHASH =
        keccak256("ValidatorSupply(bytes32 supplyCollateralSig)");

    bytes32 private constant _BORROW_TYPEHASH =
        keccak256(
            "Borrow(address apm,uint256 assets,address recipient,uint256 nonce,uint256 deadline)"
        );

    bytes32 private constant _WITHDRAW_COLLATERAL_TYPEHASH =
        0xc1292228a21656cc765f9cb8115ff5fc34b2ba76387bc5ea56d9271c84efec36;

    bytes32 private constant _CLAIM_REFUND_TYPEHASH =
        keccak256(
            "Claim(bytes32 positionId,address recipient,uint256 nonce,uint256 deadline)"
        );

    bytes32 private constant _FORCE_CLOSE_TYPEHASH =
        0x642cae269805615f67beec8139560978a19ce4dce28618a5efd6e17f6d5fc78a;

    bytes32 private constant _RESTRICT_POSITION_TYPEHASH =
        keccak256(
            "RestrictPosition(address apm,bytes32 positionId,uint8 state,uint64 deadline)"
        );

    bytes32 private constant _FINALIZE_POSITION_TYPEHASH =
        keccak256("FinalizePosition(bytes32 positionId,address apm)");

    bytes32 private constant _MORPHO_SET_AUTHORIZER_TYPEHASH =
        keccak256(
            "Authorization(address authorizer,address authorized,bool isAuthorized,uint256 nonce,uint256 deadline)"
        );

    bytes32 private constant _APM_GENERATED_TYPEHASH =
        keccak256("APMGenerated(address apm,uint256 deadline)");

    function _signSupply(
        uint256 privateKey,
        address apm,
        bytes32 id,
        uint256 assets,
        uint256 nonce,
        address morphoManagement
    ) internal view returns (bytes memory) {
        bytes32 digest = _getSupplyTypedDataHash(
            apm,
            id,
            assets,
            nonce,
            morphoManagement
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _signSetAuthorizer(
        uint256 privateKey,
        address positionManager,
        bytes32 positionId,
        bytes32 id,
        address authorizer
    ) internal view returns (bytes memory) {
        bytes32 digest = _getSetAuthorizerTypedDataHash(
            positionManager,
            positionId,
            id,
            authorizer
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _signValidatorSupply(
        uint256 privateKey,
        bytes memory supplyCollateralSignature,
        address optimexSupplier
    ) internal view returns (bytes memory) {
        bytes32 digest = _getValidatorSupplyTypedDataHash(
            supplyCollateralSignature,
            optimexSupplier
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getSupplyTypedDataHash(
        address apm,
        bytes32 id,
        uint256 assets,
        uint256 nonce,
        address morphoManagement
    ) private view returns (bytes32) {
        (, string memory name, string memory version, , , , ) = EIP712(
            morphoManagement
        ).eip712Domain();
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                morphoManagement
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(_SUPPLY_TYPEHASH, apm, id, assets, nonce)
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _getSetAuthorizerTypedDataHash(
        address positionManager,
        bytes32 positionId,
        bytes32 id,
        address authorizer
    ) private view returns (bytes32) {
        (, string memory name, string memory version, , , , ) = EIP712(
            address(positionManager)
        ).eip712Domain();
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(positionManager)
            )
        );

        // Recreate _hashTypedDataV4 logic
        bytes32 structHash = keccak256(
            abi.encode(_SET_AUTHORIZER_TYPEHASH, positionId, id, authorizer)
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _getValidatorSupplyTypedDataHash(
        bytes memory supplyCollateralSignature,
        address optimexSupplier
    ) private view returns (bytes32) {
        (, string memory name, string memory version, , , , ) = EIP712(
            address(optimexSupplier)
        ).eip712Domain();
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(optimexSupplier)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                _VALIDATOR_SUPPLY_TYPEHASH,
                keccak256(supplyCollateralSignature)
            )
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _getBorrowTypedDataHash(
        address apm,
        uint256 assets,
        address receiver,
        uint256 nonce,
        uint256 deadline,
        address morphoManagement
    ) private view returns (bytes32) {
        (, string memory name, string memory version, , , , ) = EIP712(
            morphoManagement
        ).eip712Domain();
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                morphoManagement
            )
        );

        // Recreate _hashTypedDataV4 logic
        bytes32 structHash = keccak256(
            abi.encode(_BORROW_TYPEHASH, apm, assets, receiver, nonce, deadline)
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _signBorrow(
        uint256 privateKey,
        address apm,
        uint256 assets,
        address receiver,
        uint256 nonce,
        uint256 deadline,
        address morphoManagement
    ) internal view returns (bytes memory) {
        bytes32 digest = _getBorrowTypedDataHash(
            apm,
            assets,
            receiver,
            nonce,
            deadline,
            morphoManagement
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getWithdrawCollateralTypedDataHash(
        address positionManager,
        bytes32 positionId,
        uint256 assets,
        uint256 nonce,
        uint256 deadline
    ) private view returns (bytes32) {
        (, string memory name, string memory version, , , , ) = EIP712(
            address(positionManager)
        ).eip712Domain();
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(positionManager)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                _WITHDRAW_COLLATERAL_TYPEHASH,
                positionId,
                assets,
                nonce,
                deadline
            )
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _signWithdraw(
        uint256 privateKey,
        address positionManager,
        bytes32 positionId,
        uint256 assets,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 digest = _getWithdrawCollateralTypedDataHash(
            positionManager,
            positionId,
            assets,
            nonce,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getClaimRefundTypedDataHash(
        address positionManager,
        bytes32 positionId,
        address receiver,
        uint256 nonce,
        uint256 deadline
    ) private view returns (bytes32) {
        (, string memory name, string memory version, , , , ) = EIP712(
            address(positionManager)
        ).eip712Domain();
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(positionManager)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                _CLAIM_REFUND_TYPEHASH,
                positionId,
                receiver,
                nonce,
                deadline
            )
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _signClaim(
        uint256 privateKey,
        address positionManager,
        bytes32 positionId,
        address receiver,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 digest = _getClaimRefundTypedDataHash(
            positionManager,
            positionId,
            receiver,
            nonce,
            deadline
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getForceCloseTypedDataHash(
        bytes32 positionId,
        address positionManager,
        bytes32 tradeId,
        address liquidator
    ) private view returns (bytes32) {
        (, string memory name, string memory version, , , , ) = EIP712(
            address(liquidator)
        ).eip712Domain();
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                liquidator
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                _FORCE_CLOSE_TYPEHASH,
                positionId,
                positionManager,
                tradeId
            )
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _signForceClose(
        uint256 privateKey,
        bytes32 positionId,
        address positionManager,
        bytes32 tradeId,
        address liquidator
    ) internal view returns (bytes memory) {
        bytes32 digest = _getForceCloseTypedDataHash(
            positionId,
            positionManager,
            tradeId,
            liquidator
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getRestrictPositionTypedDataHash(
        address apm,
        bytes32 positionId,
        uint8 state,
        uint64 deadline,
        address morphoManagement
    ) private view returns (bytes32) {
        (, string memory name, string memory version, , , , ) = EIP712(
            address(morphoManagement)
        ).eip712Domain();
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(morphoManagement)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                _RESTRICT_POSITION_TYPEHASH,
                apm,
                positionId,
                state,
                deadline
            )
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _signRestrictPosition(
        uint256 privateKey,
        address apm,
        bytes32 positionId,
        uint8 state,
        uint64 deadline,
        address morphoManagement
    ) internal view returns (bytes memory) {
        bytes32 digest = _getRestrictPositionTypedDataHash(
            apm,
            positionId,
            state,
            deadline,
            morphoManagement
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getFinalizePositionTypedDataHash(
        bytes32 positionId,
        address apm,
        address morphoLiquidator
    ) private view returns (bytes32) {
        (, string memory name, string memory version, , , , ) = EIP712(
            address(morphoLiquidator)
        ).eip712Domain();
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(morphoLiquidator)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(_FINALIZE_POSITION_TYPEHASH, positionId, apm)
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _signFinalizePosition(
        uint256 privateKey,
        bytes32 positionId,
        address apm,
        address morphoLiquidator
    ) internal view returns (bytes memory) {
        bytes32 digest = _getFinalizePositionTypedDataHash(
            positionId,
            apm,
            morphoLiquidator
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getMorphoSetAuthorizerTypedDataHash(
        Authorization memory authorization,
        address morpho
    ) private view returns (bytes32) {
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(uint256 chainId,address verifyingContract)"
                ),
                block.chainid,
                morpho
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(_MORPHO_SET_AUTHORIZER_TYPEHASH, authorization)
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _signMorphoSetAuthorizer(
        uint256 privateKey,
        Authorization memory authorization,
        address morpho
    ) internal view returns (bytes memory) {
        bytes32 digest = _getMorphoSetAuthorizerTypedDataHash(
            authorization,
            morpho
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getAPMGeneratedTypedDataHash(
        address apm,
        uint256 deadline,
        address morphoManagement
    ) private view returns (bytes32) {
        (, string memory name, string memory version, , , , ) = EIP712(
            address(morphoManagement)
        ).eip712Domain();
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(morphoManagement)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(_APM_GENERATED_TYPEHASH, apm, deadline)
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _signAPMGenerated(
        uint256 privateKey,
        address apm,
        uint256 deadline,
        address morphoManagement
    ) internal view returns (bytes memory) {
        bytes32 digest = _getAPMGeneratedTypedDataHash(
            apm,
            deadline,
            morphoManagement
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
