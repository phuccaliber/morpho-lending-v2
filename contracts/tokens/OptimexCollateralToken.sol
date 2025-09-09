// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../libraries/ErrorLib.sol";
import "../interfaces/IOptimexCollateralToken.sol";

/// @title OptimexCollateralToken
/// @notice Abstract ERC20 token contract that provides controlled token circulation for the Optimex protocol
/// @dev This contract implements a vault-based token system where tokens are held in the contract
///      and can only be allocated to authorized recipients. It uses transient storage for security
///      and gas efficiency, following EIP-1153 best practices.
///
/// @dev Token circulation is controlled through a permitted recipient mechanism that automatically
///      resets after each transaction, ensuring secure token transfers.
///
/// @dev Inheriting contracts must implement access control and define specific roles for minting,
///      allocation, and recipient management.
abstract contract OptimexCollateralToken is ERC20, IOptimexCollateralToken {
    /// @dev The address permitted to receive tokens during transfers
    /// Uses transient storage to avoid permanent storage costs
    /// Automatically resets to address(0) after each transaction
    address transient permittedRecipient;

    /// @dev The number of decimals used for the token
    /// Overrides the default 18 decimals to match the underlying token's decimal places
    uint8 immutable _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 initDecimals
    ) ERC20(name, symbol) {
        _decimals = initDecimals;
    }

    /**
        @notice Returns the number of decimals used for the token
        @return The number of decimals
    */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
        @notice Mints tokens to itself when increasing the token's supply
        @dev Newly minted tokens are held by the contract itself, out of circulation
        @param amount Amount of tokens to mint
    */
    function _mint(uint256 amount) internal virtual {
        require(amount > 0, ErrorLib.ZeroAmount());

        _mint(address(this), amount);

        emit Minted(msg.sender, amount);
    }

    /**
        @notice Allocates tokens from itself to a recipient
        @param to Address to receive the tokens
        @param amount Amount of tokens to transfer
    */
    function _allocateTo(address to, uint256 amount) internal virtual {
        require(to != address(0), ErrorLib.ZeroAddress());
        require(
            amount > 0 && amount <= balanceOf(address(this)),
            ErrorLib.InvalidAmount()
        );

        /// @dev Transfer tokens from itself to the recipient
        /// which requires the recipient to be authorized via `_permit()``
        _permit(to);
        _transfer(address(this), to, amount);

        emit TokenAllocated(msg.sender, to, amount);
    }

    /**
        @notice Sets the `permittedRecipient` address
        @dev `permittedRecipient` is a transient storage variable that resets 
            after each transaction, preventing reuse in subsequent transactions
        @param recipient The address authorized to receive tokens
    */
    function _permit(address recipient) internal virtual {
        permittedRecipient = recipient;

        emit Permit(msg.sender, recipient);
    }

    /**
        @notice Burns the current balance of the contract
        @dev This function will burn the current balance of the contract
    */
    function _burnSelf() internal virtual {
        uint256 selfBalance = balanceOf(address(this));
        if (selfBalance > 0) {
            _burn(address(this), selfBalance);
            emit Burned(msg.sender, selfBalance);
        }
    }

    /**
        @notice Override of the `_update()` function from the ERC-20 implementation
        @dev Adds special constraints to ensure that tokens can only be transferred
          to the allowed recipient or the contract itself:
            - recipient != address(this): in circulation
            - recipient == address(this): out of circulation
    */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (!(to == address(this) || to == permittedRecipient)) {
            revert ErrorLib.RecipientNotPermitted(to);
        }
        super._update(from, to, amount);

        if (to == address(this))
            emit TokenDeallocated(msg.sender, from, amount);

        /// Resets `permittedRecipient` to address(0) as a security measure to prevent
        /// potential reuse of the previously permitted address in subsequent transactions,
        /// in accordance with EIP-1153 transient storage best practices:
        /// https://eips.ethereum.org/EIPS/eip-1153#security-considerations
        permittedRecipient = address(0);
    }
}
