import "@morpho-blue/libraries/MarketParamsLib.sol";

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IMorphoManagement {
    event APMCreated(
        address indexed apm,
        address indexed authorizer,
        address indexed validator
    );

    event Supplied(
        address indexed apm,
        bytes32 indexed marketId,
        uint256 assets,
        uint256 loanCounter
    );

    /**
        @notice Event emitted when assets are borrowed from a position on Morpho
        @param apm The unique address of the APM, specify the position on Morpho
        @param marketId The unique identifier of the Morpho market
        @param amount The amount of assets borrowed
        @param recipient The address to receive the borrowed assets
        @dev Related function: borrow()
    */
    event Borrowed(
        address indexed apm,
        bytes32 indexed marketId,
        uint256 amount,
        address recipient
    );

    /**
        @notice Event emitted when assets are repaid to a position on Morpho
        @param apm The unique address of the APM, specify the position on Morpho
        @param marketId The unique identifier of the Morpho market
        @param assetsRepaid The amount of assets repaid
        @param sharesRepaid The amount of shares repaid
        @param repayer The address repaying the assets
        @dev Related function: repay()
    */
    event Repaid(
        address indexed apm,
        bytes32 indexed marketId,
        uint256 assetsRepaid,
        uint256 sharesRepaid,
        address repayer
    );

    /**
        @notice Event emitted when collateral is withdrawn from a position on Morpho
        @param apm The unique address of the APM, specify the position on Morpho
        @param marketId The unique identifier of the Morpho market
        @param amount The amount of collateral withdrawn
        @dev Related function: withdraw()
    */
    event Withdrawn(
        address indexed apm,
        bytes32 indexed marketId,
        uint256 amount
    );

    /**
        @notice Event emitted when collateral is forcibly withdrawn from a position on Morpho
        @param operator The address performing the withdrawal
        @param apm The unique address of the APM, specify the position on Morpho
        @param marketId The unique identifier of the Morpho market
        @param withdrawnAssets The amount of collateral withdrawn
        @param surplus The left-over amount of loan tokens transferred to the AccountPositionManager
        @dev Related function: forceClose()
    */
    event ForceClosed(
        address indexed operator,
        address indexed apm,
        bytes32 indexed marketId,
        uint256 withdrawnAssets,
        uint256 surplus
    );

    /**
        @notice Emitted when Morpho calls the `onMorphoRepay` callback
        @param repaidAssets The amount of loan tokens repaid to Morpho
        @param data Additional data for the repayment callback: (sender, loanToken)
        @dev Related function: `onMorphoRepay`
    */
    event OnMorphoRepay(uint256 repaidAssets, bytes data);

    /**
        @notice Supply collateral to an apm'position on Morpho
        @dev Called by anyone, but requires valid signature from the authorizer
        @dev The position can be supplied collateral if and only if:
          - The lending protocol is not "paused"
          - The position's permission state is FULL_ACCESS
        @param apm The unique address of the APM, specify the position on Morpho
        @param assets The amount of assets to supply
        @param marketParams The Morpho market parameters
        @param sig Signature from authorizer approving the collateral supply
    */
    function supply(
        address apm,
        uint256 assets,
        MarketParams calldata marketParams,
        bytes calldata sig
    ) external;

    /**
        @notice Withdraw collateral from a position on Morpho
        @dev Called by anyone, but requires valid signature from the authorizer
        @dev The position's collateral can be withdrawn even when:
          - The lending protocol is currently being paused by the Admin
          - The position's permission state is EXIT_ONLY or REPAY_WITHDRAW
        @param apm The unique address of the APM, specify the position on Morpho
        @param assets The collateral amount to withdraw
        @param deadline The withdrawal deadline
        @param marketParams The Morpho market parameters
        @param signature The signature from the authorizer approving the withdrawal operation
    */
    function withdraw(
        address apm,
        uint256 assets,
        uint256 deadline,
        MarketParams calldata marketParams,
        bytes calldata signature
    ) external;

    /**
        @notice Forcibly withdraw collateral and close a position on Morpho
        @dev Called by the MorphoLiquidator contract only
        @dev The position can be force-closed even when:
          - The lending protocol is currently being paused by the Admin
          - The position's permission state is EXIT_ONLY or REPAY_WITHDRAW
        @param apm The unique address of the APM, specify the position on Morpho
        @param assets The collateral amount to withdraw
        @param surplus The left-over amount that can be claimed later
        @param marketParams The Morpho market parameters
    */
    function forceClose(
        address apm,
        uint256 assets,
        uint256 surplus,
        MarketParams calldata marketParams
    ) external;

    // /**
    //     @notice Queries the current status of the MorphoManagement contract
    //     @return isPaused Boolean flag to indicate if the lending protocol is paused
    // */
    // function paused() external view returns (bool isPaused);

    /**
        @notice Queries the address of the Morpho contract
        @return The address of the Morpho contract
    */
    function MORPHO() external view returns (address);

    /**
        @notice Queries the address of the OptimexBTC token
        @return The address of the OptimexBTC token
    */
    function OBTC() external view returns (address);

    /**
        @notice Queries the validator of a specified `apm`
        @param apm The user's AccountPositionManager to query
        @return validator The validator address assigned to this `apm`
    */
    function apmValidators(
        address apm
    ) external view returns (address validator);

    /**
        @notice Checks if the provided `account` has been granted the `role`
        @param role The role to check
        @param account The address to check
        @return True if the address has been granted the role, false otherwise
    */
    function isAuthorized(
        bytes32 role,
        address account
    ) external view returns (bool);

    // /**
    //     @notice Checks the validity of the provided `apm`
    //     @param apm The address to check for validity
    //     @dev Reverts if the provided address is not a valid AccountPositionManager
    // */
    // function validateAPM(address apm) external view;

    /**
        @notice Queries the address set as the protocol fee receiver
        @return The address configured as the protocol fee receiver
    */
    function getPFeeAddress() external view returns (address);

    /**
        @notice Queries the configurations for a specified `apm`
        @param apm The user's AccountPositionManager to query
        @return morpho The address of the Morpho contract
        @return oBTC The address of the OptimexBTC token
        @return validator The validator address assigned to this `apm`
    */
    function getAPMConfigurations(
        address apm
    ) external view returns (address morpho, address oBTC, address validator);
}
