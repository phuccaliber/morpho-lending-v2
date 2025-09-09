// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../libraries/ErrorLib.sol";
import "../interfaces/IOptimexProtocol.sol";

/// @title OptimexAdminGuard
/// @notice Access control contract that provides admin-only functionality.
/// @dev This contract serves as a base contract for other Optimex contracts that need admin access control.
contract OptimexAdminGuard {
    /// @dev Address of the OptimexProtocol contract
    IOptimexProtocol internal _protocol;

    /**
        @notice Emitted when the OptimexProtocol address is updated.
        @param operator The address of the caller (owner) who performed the update.
        @param newProtocol The new OptimexProtocol contract address.
        @dev Related function: `setProtocol()`
    */
    event ProtocolUpdated(
        address indexed operator,
        address indexed newProtocol
    );

    modifier onlyAdmin() {
        address sender = msg.sender;
        if (sender != _getProtocol().owner())
            revert ErrorLib.Unauthorized(sender);
        _;
    }

    constructor(IOptimexProtocol protocol) {
        _protocol = protocol;
    }

    /**
        @notice Returns the current address of the OptimexProtocol contract.
        @dev Can be called by anyone.
        @return protocol The OptimexProtocol address.
    */
    function getProtocol() external view returns (address protocol) {
        protocol = address(_getProtocol());
    }

    /** 
        @notice Updates the OptimexProtocol contract to a new address.
        @dev Caller must be the current Admin of the OptimexProtocol contract.
        @param newProtocol The new OptimexProtocol contract address.
    */
    function setProtocol(address newProtocol) external onlyAdmin {
        if (newProtocol == address(0)) revert ErrorLib.ZeroAddress();

        _protocol = IOptimexProtocol(newProtocol);

        emit ProtocolUpdated(msg.sender, newProtocol);
    }

    function _isAuthorized(
        bytes32 role,
        address account
    ) internal view virtual returns (bool) {
        return _getProtocol().hasRole(role, account);
    }

    function _getProtocol() internal view virtual returns (IOptimexProtocol) {
        return _protocol;
    }
}
