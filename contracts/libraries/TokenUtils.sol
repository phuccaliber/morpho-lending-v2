// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title TokenUtils
/// @notice Provides utility functions for token operations
/// @dev Designed as a library to be used by other Optimex contracts
library TokenUtils {
    using SafeERC20 for IERC20;

    /**
        @notice Approves the spender to spend a specific amount of tokens
        @dev Use SafeERC20 to deal with legacy ERC20 tokens
        @param token The address of the token
        @param spender The address of the spender
        @param amount The amount of tokens to approve
    */
    function approval(IERC20 token, address spender, uint256 amount) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);

        if (oldAllowance > amount) {
            token.safeDecreaseAllowance(spender, oldAllowance - amount);
        } else if (oldAllowance < amount) {
            token.safeIncreaseAllowance(spender, amount - oldAllowance);
        }
    }
}
