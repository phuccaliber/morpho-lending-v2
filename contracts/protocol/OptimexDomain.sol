// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @title Optimex Domain Information
/// @notice Provides a standardized way to expose the contract's name and version.
/// @dev Designed as an abstract base contract to be inherited by other Optimex contracts.
abstract contract OptimexDomain {
    /// @notice The name identifier for the Optimex contract domain.
    string internal _name;

    /// @notice The version identifier for the Optimex contract domain.
    string internal _version;

    constructor(string memory name, string memory version) {
        _name = name;
        _version = version;
    }

    /**
        @notice Returns the domain information of the Optimex contract.
        @dev Can be called by anyone
        @return name The name of the contract.
        @return version The current version of the contract.
    */
    function optimexDomain()
        external
        view
        virtual
        returns (string memory name, string memory version)
    {
        name = _name;
        version = _version;
    }
}
