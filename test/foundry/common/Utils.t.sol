/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

contract Utils is Test {
    bytes32 private constant _SET_AUTHORIZER_TYPEHASH =
        0x8ffe98054fd6401af07e7471e50e6a855a3edb1246ede4d5d35e79a29167a7e8;

    bytes32 private constant _SUPPLY_TYPEHASH =
        0x84ab0c5bb221021e7bdc822d1a59f8c97e0a560365811e7ee025254a496bf9de;

    bytes32 private constant _VALIDATOR_SUPPLY_TYPEHASH =
        0x7c598e158f51047a7e20707868c0cac036de69f4df3522bbabd94771f8324f9a;

    bytes32 private constant _BORROW_TYPEHASH =
        keccak256(
            "Borrow(bytes32 positionId,uint256 assets,address recipient,uint256 nonce,uint256 deadline)"
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

    function _signSupply(
        uint256 privateKey,
        address positionManager,
        bytes32 positionId,
        bytes32 id,
        uint256 assets,
        uint256 nonce
    ) internal view returns (bytes memory) {
        bytes32 digest = _getSupplyTypedDataHash(
            positionManager,
            positionId,
            id,
            assets,
            nonce
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
        address positionManager,
        bytes memory authSetAuthorizerSignature,
        bytes memory supplyCollateralSignature,
        address optimexSupplier
    ) internal view returns (bytes memory) {
        bytes32 digest = _getValidatorSupplyTypedDataHash(
            positionManager,
            authSetAuthorizerSignature,
            supplyCollateralSignature,
            optimexSupplier
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getSupplyTypedDataHash(
        address positionManager,
        bytes32 positionId,
        bytes32 id,
        uint256 assets,
        uint256 nonce
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
            abi.encode(_SUPPLY_TYPEHASH, positionId, id, assets, nonce)
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
        address positionManager,
        bytes memory authSetAuthorizerSignature,
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
                positionManager,
                keccak256(authSetAuthorizerSignature),
                keccak256(supplyCollateralSignature)
            )
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function _getBorrowTypedDataHash(
        address positionManager,
        bytes32 positionId,
        uint256 assets,
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

        // Recreate _hashTypedDataV4 logic
        bytes32 structHash = keccak256(
            abi.encode(
                _BORROW_TYPEHASH,
                positionId,
                assets,
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

    function _signBorrow(
        uint256 privateKey,
        address positionManager,
        bytes32 positionId,
        uint256 assets,
        address receiver,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 digest = _getBorrowTypedDataHash(
            positionManager,
            positionId,
            assets,
            receiver,
            nonce,
            deadline
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
}
