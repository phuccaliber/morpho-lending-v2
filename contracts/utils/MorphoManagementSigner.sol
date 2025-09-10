// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title MorphoManagementSigner
/// @notice Provides signature verification utilities for MorphoManagement operations
contract MorphoManagementSigner is EIP712 {
    using ECDSA for bytes32;

    /// @notice EIP-712 typehash for setting the permission state of a position
    /// @dev keccak256("RestrictPosition(address apm,bytes32 positionId,uint8 state,uint64 deadline)")
    bytes32 private constant _RESTRICT_POSITION_TYPEHASH =
        0x7422df70bffc02124c5e0bbb0185d9e617c274e2067c6b6de08a650a2fab174a;

    /// @notice EIP-712 typehash for supplying collateral to an apm
    /// @dev keccak256("SupplyCollateral(address apm,bytes32 marketId,uint256 assets,uint256 nonce)")
    bytes32 private constant _SUPPLY_TYPEHASH =
        0x08ae5b019b96dfc6531fe4156aafc1cf288947578b56a9430efc623bbadc8e33;

    /// @notice EIP-712 typehash for the borrow operation
    /// @dev keccak256("Borrow(address apm,uint256 assets,address recipient,uint256 nonce,uint256 deadline)");
    bytes32 private constant _BORROW_TYPEHASH =
        0xda4b426f381fd2bc183e218eed1c34a6dd86c29a586381f9a768a14889422ebb;

    /// @notice EIP-712 typehash for verifying the APM generation
    /// @dev keccak256("APMGenerated(address apm,uint256 deadline)")
    bytes32 private constant _APM_GENERATED_TYPEHASH =
        0xb2ed236e73990dd0bd6e7536cdd27e9f18b33c0f4fbc9e3d00dc42602de9177d;

    constructor(
        string memory name,
        string memory version
    ) EIP712(name, version) {}

    // /**
    //     @notice Recovers the signer address that signed the permission state change operation
    //     @param apm The address of the AccountPositionManager
    //     @param positionId The unique identifier of the Optimex position
    //     @param state The permission state to set
    //     @param deadline The timestamp after which the signature expires
    //     @param signature The EIP-712 signature
    //     @return signer The recovered signer address
    // */
    // function _getSigner(
    //     address apm,
    //     bytes32 positionId,
    //     Permission state,
    //     uint64 deadline,
    //     bytes memory signature
    // ) internal view returns (address signer) {
    //     bytes32 hash = _hashTypedDataV4(
    //         keccak256(
    //             abi.encode(
    //                 _RESTRICT_POSITION_TYPEHASH,
    //                 apm,
    //                 positionId,
    //                 state,
    //                 deadline
    //             )
    //         )
    //     );
    //     signer = hash.recover(signature);
    // }

    /**
        @notice Recovers the signer address that signed the APM generation
        @param apm The address of the AccountPositionManager
        @param deadline The timestamp after which the signature expires
        @param signature The EIP-712 signature
        @return signer The recovered signer address
    */
    function _getDelegatorSigner(
        address apm,
        uint256 deadline,
        bytes memory signature
    ) internal view returns (address signer) {
        bytes32 hash = _hashTypedDataV4(
            keccak256(abi.encode(_APM_GENERATED_TYPEHASH, apm, deadline))
        );
        signer = hash.recover(signature);
    }

    function _verifySupplySig(
        address signer,
        address apm,
        bytes32 marketId,
        uint256 assets,
        uint256 nonce,
        bytes calldata signature
    ) internal view returns (bool isValid) {
        bytes32 hash = _hashTypedDataV4(
            keccak256(
                abi.encode(_SUPPLY_TYPEHASH, apm, marketId, assets, nonce)
            )
        );
        isValid = signer == hash.recover(signature);
    }

    /**
        @notice Verifies a signature for a borrow operation, signed by the authorizer
        @dev Confirms that the authorizer has approved borrowing the specified assets
        @param signer The expected signer address (should be the position's authorizer)
        @param apm The unique address of the APM, specify the position on Morpho
        @param assets The amount of assets to borrow
        @param recipient The address to receive the borrowed assets
        @param nonce The nonce used in the signature
        @param deadline The signature deadline
        @param signature The signature to verify
        @return isValid true if the signature is signed by the authorizer, false otherwise
    */
    function _verifyBorrowSig(
        address signer,
        address apm,
        uint256 assets,
        address recipient,
        uint256 nonce,
        uint256 deadline,
        bytes memory signature
    ) internal view returns (bool isValid) {
        bytes32 hash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _BORROW_TYPEHASH,
                    apm,
                    assets,
                    recipient,
                    nonce,
                    deadline
                )
            )
        );
        isValid = hash.recover(signature) == signer;
    }
}
