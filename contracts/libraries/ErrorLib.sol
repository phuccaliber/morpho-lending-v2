// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @title ErrorLib
/// @notice Provides common error messages for the Optimex protocol
/// @dev Designed as a library to be used by other Optimex contracts
library ErrorLib {
    error AccessDenied(bytes32 positionId);
    error AuthorizerMismatch();
    error DeadlineExpired();
    error InvalidAmount();
    error InvalidAPM();
    error InvalidAuthorizerSig();
    error InvalidOwnerSig();
    error InvalidPositionId(bytes32 positionId);
    error InvalidPubkey();
    error InvalidValidator(address validator);
    error MarketMismatch(bytes32 expected, bytes32 actual);
    error RecipientNotPermitted(address recipient);
    error StateAlreadySet();
    error TokenMismatch(address expected, address actual);
    error Unauthorized(address sender);
    error ZeroAddress();
    error ZeroAmount();
    error InvalidBorrowShares();
}
