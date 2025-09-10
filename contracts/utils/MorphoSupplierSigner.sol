// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title MorphoSupplierSigner
/// @notice Provides signature verification utilities for the MorphoSupplier
contract MorphoSupplierSigner is EIP712 {
    using ECDSA for bytes32;

    /// @notice EIP-712 typehash for validator supply operations
    /// @dev keccak256("ValidatorSupply(bytes32 supplyCollateralSig)")
    bytes32 private constant _VALIDATOR_SUPPLY_TYPEHASH =
        0x00702ed72ecebc71efd3d00d5e061d9e69d5feef1c137a2faa779f9205d30266;

    constructor(
        string memory name,
        string memory version
    ) EIP712(name, version) {}

    /**
        @notice Recovers the signer address that approved the supply operation
        @param supplyCollateralSig Signature from authorizer approving the supply
        @param signature The signature to verify
        @return signer The address of the recovered signer
    */
    function _getSigner(
        bytes memory supplyCollateralSig,
        bytes memory signature
    ) internal view returns (address signer) {
        bytes32 hash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _VALIDATOR_SUPPLY_TYPEHASH,
                    keccak256(supplyCollateralSig)
                )
            )
        );
        signer = hash.recover(signature);
    }
}
