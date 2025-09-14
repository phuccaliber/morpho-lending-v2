// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title MorphoLiquidatorSigner
/// @notice Provides signature verification utilities for the MorphoLiquidator
contract MorphoLiquidatorSigner is EIP712 {
    using ECDSA for bytes32;

    /// @notice EIP-712 typehash for force close operations
    /// @dev keccak256("ForceClose(address apm,bytes32 tradeId)");
    bytes32 private constant _FORCE_CLOSE_TYPEHASH =
        0x00ec65eea1fc5f9b473965fcd39b70e1d70bb93223ba2fbb4c15e5758148c422;

    /// @notice EIP-712 typehash for close position operations
    /// @dev keccak256("FinalizePosition(bytes32 positionId,address apm)")
    bytes32 private constant _FINALIZE_POSITION_TYPEHASH =
        0x6a91c9d686fb5ae77b56af7d61de27c4669ec7b62e85f86bcb624fbf1ab2320f;

    constructor(
        string memory name,
        string memory version
    ) EIP712(name, version) {}

    /**
        @notice Recovers the signer address that approved the force close operation
        @param apm The AccountPositionManager contract to be forcibly closed
        @param tradeId The unique identifier of the Optimex trade
        @param signature The signature to verify
        @return signer The recovered signer address
    */
    function _getForceCloseSigner(
        address apm,
        bytes32 tradeId,
        bytes calldata signature
    ) internal view returns (address signer) {
        bytes32 hash = _hashTypedDataV4(
            keccak256(
                abi.encode(_FORCE_CLOSE_TYPEHASH, apm, tradeId)
            )
        );

        signer = ECDSA.recover(hash, signature);
    }

    /**
        @notice Recovers the signer address that approved the close position operation
        @param positionId The unique identifier of the Optimex position
        @param apm The AccountPositionManager contract to be forcibly closed
        @param signature The signature to verify
        @return signer The recovered signer address
     */
    function _getFinalizePositionSigner(
        bytes32 positionId,
        address apm,
        bytes calldata signature
    ) internal view returns (address signer) {
        bytes32 hash = _hashTypedDataV4(
            keccak256(abi.encode(_FINALIZE_POSITION_TYPEHASH, positionId, apm))
        );

        signer = ECDSA.recover(hash, signature);
    }
}
