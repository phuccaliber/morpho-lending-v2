// SPDX-License-Identifier: None
pragma solidity ^0.8.20;

import "./IProtocol.sol";

interface IOptimexProtocol is IProtocol {
    /**
        @notice Checks whether the specified `account` has been granted the given `role`.
        @param role The role to check, represented as a `bytes32` value.
        @param account The address of the account to check.
        @return `true` if the `account` has been granted the `role`, otherwise `false`.
    */
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);
}
