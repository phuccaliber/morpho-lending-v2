// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./OptimexCollateralToken.sol";
import "../protocol/OptimexAdminGuard.sol";
import "../interfaces/IOptimexProtocol.sol";
import "../libraries/ErrorLib.sol";

/// @title OptimexBTC
/// @notice ERC20 token that represents a user's locked BTC within the Optimex Protocol.
///
/// @dev ⚠️ IMPORTANT ⚠️:
/// - Do NOT treat this token as a general-purpose ERC20.
/// This token is NOT freely transferable like WBTC or other wrapped assets.
///
/// - Used exclusively as collateral within the Optimex ecosystem.
/// It cannot leave the Optimex system, and has zero market value outside it.
///
/// - Transfer is intentionally restricted to prevent peer-to-peer trading.
///
/// @dev The design choices for this token are defined in `documents/OptimexCollateralToken.md`
///
/// @dev Token has 8 decimals to match BTC's decimal places
///
/// @dev The token is managed through the access control contract defined in `OptimexAdminGuard`
contract OptimexBTC is OptimexCollateralToken, OptimexAdminGuard {
    /// keccak256("OBTC_MINTER_ROLE")
    bytes32 private constant _MINTER =
        0x1fb13e0e048d7988cdf74324e97bbd7d3b6393ce805f6db1577b4f96561f1dc5;

    /// keccak256("OBTC_RECIPIENT_CONTROLLER_ROLE")
    bytes32 private constant _RECIPIENT_CONTROLLER =
        0xaa04bf3577aad0ae45d83c7320d39212b80b1bbd88cc20f612566f0f9584481a;

    /// keccak256("OBTC_ALLOCATOR_ROLE")
    bytes32 private constant _ALLOCATOR =
        0x2b2dded60700d8321831cfd3888c50a36034d483c92e711e0359ef9a506ae053;

    modifier onlyRole(bytes32 role) {
        address sender = msg.sender;
        require(_isAuthorized(role, sender), ErrorLib.Unauthorized(sender));
        _;
    }

    constructor(
        uint256 initSupply,
        address initProtocol
    )
        OptimexCollateralToken("Optimex Collateral BTC", "oBTC", 8)
        OptimexAdminGuard(IOptimexProtocol(initProtocol))
    {
        require(initProtocol != address(0), ErrorLib.ZeroAddress());
        if (initSupply > 0) _mint(initSupply);
    }

    /**
        @notice Mints the specified amount of tokens to itself
        @dev Caller must have the MINTER role
        @dev Burns the contract’s existing balance and mints the exact specified amount.
        @param amount Amount of tokens to mint
    */
    function mint(uint256 amount) external onlyRole(_MINTER) {
        _burnSelf();

        _mint(amount);
    }

    /**
        @notice Allocates tokens to an authorized recipient
        @dev Caller must have the ALLOCATOR role
        @param to Address to transfer tokens to
        @param amount Amount of tokens to transfer
    */
    function allocateTo(
        address to,
        uint256 amount
    ) external onlyRole(_ALLOCATOR) {
        _allocateTo(to, amount);
    }

    /**
        @notice Sets the `permittedRecipient` address
        @dev Caller must have the RECIPIENT_CONTROLLER role
        @dev `permittedRecipient` is a transient storage variable that resets 
            after each transaction, preventing reuse in subsequent transactions
        @param recipient The address authorized to receive tokens
    */
    function permit(
        address recipient
    ) external onlyRole(_RECIPIENT_CONTROLLER) {
        _permit(recipient);
    }
}
