// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import "@morpho-blue/libraries/MarketParamsLib.sol";

import "./protocol/OptimexDomain.sol";
import "./interfaces/IOptimexCollateralToken.sol";
import "./interfaces/IMorphoManagement.sol";
import "./libraries/ErrorLib.sol";
import "./utils/MorphoSupplierSigner.sol";

/// @title MorphoSupplier
/// @notice Secure validator gateway for collateral supply to Morpho markets
contract MorphoSupplier is
    OptimexDomain,
    MorphoSupplierSigner,
    ReentrancyGuardTransient
{
    using MarketParamsLib for MarketParams;

    /// @dev The address of the Morpho management contract
    IMorphoManagement public immutable MORPHO_MANAGEMENT;

    /**
        @notice Emitted when a validator successfully supplies collateral to user's position on Morpho
        @param validator The validator address that approved the supply operation
        @param apm The address of the user's AccountPositionManager
        @param marketId The unique identifier of the Morpho market
        @param amount The amount of collateral supplied
        @param authorizer The authorizer that approved the supply
    */
    event Supply(
        address indexed validator,
        address indexed apm,
        bytes32 marketId,
        uint256 amount,
        address authorizer
    );

    constructor(
        address morphoManagement,
        string memory name,
        string memory version
    )
        MorphoSupplierSigner("MorphoSupplier Signature Verifier", version)
        OptimexDomain(name, version)
    {
        require(morphoManagement != address(0), ErrorLib.ZeroAddress());

        MORPHO_MANAGEMENT = IMorphoManagement(morphoManagement);
    }

    /**
        @notice Supply collateral to user's position on Morpho
        @dev Can be called by anyone, but requires valid signatures to proceed
        @param apm The user's AccountPositionManager used to supply collateral
        @param authorizer The address authorized to manage the position
        @param amount The amount of collateral to supply
        @param marketParams The market parameters identifying the Morpho market
        @param supplyCollateralSig Signature from authorizer approving the supply
        @param validatorSig Signature from validator approving the supply operation
    */
    function supply(
        address apm,
        address authorizer,
        uint256 amount,
        MarketParams calldata marketParams,
        bytes calldata supplyCollateralSig,
        bytes calldata validatorSig
    ) external nonReentrant {
        address collateralToken = marketParams.collateralToken;
        (address morpho, address oBTC, address validator) = MORPHO_MANAGEMENT
            .getAPMConfigurations(apm);
        require(authorizer != address(0), ErrorLib.ZeroAddress());
        require(
            collateralToken == oBTC,
            ErrorLib.TokenMismatch(oBTC, collateralToken)
        );

        /// Verify that the validator approved the supply operation
        address signer = _getSigner(supplyCollateralSig, validatorSig);
        require(signer == validator, ErrorLib.InvalidValidator(signer));

        IOptimexCollateralToken token = IOptimexCollateralToken(
            collateralToken
        );
        token.allocateTo(address(MORPHO_MANAGEMENT), amount);

        /// @dev Set Morpho as the permitted recipient before calling the APM to execute the supply
        token.permit(address(morpho));
        MORPHO_MANAGEMENT.supply(
            apm,
            amount,
            marketParams,
            supplyCollateralSig
        );

        emit Supply(
            signer,
            apm,
            Id.unwrap(marketParams.id()),
            amount,
            authorizer
        );
    }
}
