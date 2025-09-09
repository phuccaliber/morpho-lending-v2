// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

import "./OptimexDomain.sol";
import "../libraries/ErrorLib.sol";

contract OptimexProtocol is AccessControlDefaultAdminRules, OptimexDomain {
    /// @dev Address of Protocol Fee receiver
    /// Note: DO NOT change this variable name. It's been using by other contracts
    address public pFeeAddr;

    /**
        @notice Emitted when the Protocol Fee Receiver address is updated.
        @param operator The address of the caller (Owner) who performed the update.
        @param newPFeeAddr The new Protocol Fee Receiver address.
        @dev Related function: `setPFeeAddress()`.
    */
    event PFeeAddressUpdated(address indexed operator, address newPFeeAddr);

    constructor(
        uint48 initialDelay,
        address initialDefaultAdmin,
        address pFeeAddr_,
        string memory name,
        string memory version
    )
        AccessControlDefaultAdminRules(initialDelay, initialDefaultAdmin)
        OptimexDomain(name, version)
    {
        pFeeAddr = pFeeAddr_;
    }

    /**
        @notice Sets a new Protocol Fee Receiver address.
        @dev Caller must be the current `Owner`.
        @param newPFeeAddr The new address to receive protocol fees.
    */
    function setPFeeAddress(
        address newPFeeAddr
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newPFeeAddr == address(0)) revert ErrorLib.ZeroAddress();

        pFeeAddr = newPFeeAddr;

        emit PFeeAddressUpdated(_msgSender(), newPFeeAddr);
    }
}
