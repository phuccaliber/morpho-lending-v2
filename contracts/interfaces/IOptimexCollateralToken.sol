// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IOptimexCollateralToken is IERC20 {
    /**
        @notice Emitted when a recipient is approved for token transfers
        @param operator The address that grants the permission
        @param recipient The address authorized to receive tokens
        @dev Related function: _permit()
    */
    event Permit(address indexed operator, address indexed recipient);

    /**
        @notice Emitted when tokens are minted
        @param operator The address that requested the minting operation
        @param amount The amount of tokens minted
        @dev Related function: _mint()
    */
    event Minted(address indexed operator, uint256 amount);

    /**
        @notice Emitted when tokens are burned
        @param operator The address that requested the burning operation
        @param amount The amount of tokens burned
        @dev Related function: _burnSelf()
    */
    event Burned(address indexed operator, uint256 amount);

    /**
        @notice Emitted when tokens are allocated to a destination address
        @param operator The address that performed the allocation
        @param to The address that received the tokens
        @param amount The amount of tokens allocated
        @dev Related function: _allocateTo()
    */
    event TokenAllocated(
        address indexed operator,
        address indexed to,
        uint256 amount
    );

    /**
        @notice Emitted when tokens are deallocated from a source address
        @param operator The address that performed the deallocation
        @param from The address that had tokens deallocated
        @param amount The amount of tokens deallocated
        @dev Related function: _update()
    */
    event TokenDeallocated(
        address indexed operator,
        address indexed from,
        uint256 amount
    );

    /**
        @notice Mints the specified amount of tokens to itself
        @dev Used when increasing the token's supply, and newly minted tokens
            are held by the contract itself
        @param amount Amount of tokens to mint
    */
    function mint(uint256 amount) external;

    /**
        @notice Allocates tokens to an authorized recipient
        @param to Address to transfer tokens to
        @param amount Amount of tokens to transfer
    */
    function allocateTo(address to, uint256 amount) external;

    /**
        @notice Sets the `permittedRecipient` address
        @dev `permittedRecipient` is a transient storage variable that resets 
            after each transaction, preventing reuse in subsequent transactions
        @param recipient The address authorized to receive tokens
    */
    function permit(address recipient) external;
}
