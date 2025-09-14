// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import "@morpho-blue/libraries/MarketParamsLib.sol";
import "@morpho-blue/libraries/MathLib.sol";
import "@morpho-blue/libraries/UtilsLib.sol";
import "@morpho-blue/libraries/SharesMathLib.sol";
import "@morpho-blue/libraries/ConstantsLib.sol";
import "@morpho-blue/interfaces/IOracle.sol";
import "@morpho-blue/interfaces/IMorpho.sol";
import "@morpho-blue/interfaces/IMorphoCallbacks.sol";

import "./protocol/OptimexDomain.sol";
import "./interfaces/IOptimexCollateralToken.sol";
import "./interfaces/IMorphoManagement.sol";
import "./libraries/ErrorLib.sol";
import "./libraries/TokenUtils.sol";
import "./utils/MorphoLiquidatorSigner.sol";

/// @title MorphoLiquidator
/// @notice A comprehensive liquidation and force-close contract for the Optimex Protocol that enables liquidators to:
///   - Liquidate undercollateralized positions by repaying debt and seizing collateral
///   - Force-close positions with validator approval by repaying full debt
///   - Manage profit distribution and user surplus during liquidation processes
contract MorphoLiquidator is
    OptimexDomain,
    MorphoLiquidatorSigner,
    IMorphoLiquidateCallback,
    IMorphoRepayCallback,
    ReentrancyGuardTransient
{
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;
    using MathLib for uint128;
    using UtilsLib for uint256;
    using SharesMathLib for uint256;
    using SafeERC20 for IERC20;
    using TokenUtils for IERC20;

    /// @notice Struct to store the result of a payment operation: liquidation or repayment
    /// @param seizedCollateral The amount of collateral being seized from the position
    /// @param remainCollateral The portion of collateral that remains after seizure
    /// @param repaidDebt The amount of debt repaid to Morpho
    /// @param surplus The left-over amount being returned to the AccountPositionManager
    /// @param profit The amount being taken as profit
    ///
    /// @dev
    /// - On liquidation, the `seizedCollateral` is calculated by Morpho based on the `borrowShares`
    /// - On repayment, the `seizedCollateral` is set to `0`
    ///
    /// @dev
    /// - On liquidation, the `remainCollateral` is the portion of collateral that remains after seizure
    /// - On repayment, the `remainCollateral` is set to `totalCollateral`.
    ///   The AccountPositionManager can then withdraw the full amount of collateral
    ///   and transfer it back to the ERC-20 contract for removal from circulation
    struct PaymentResult {
        uint256 seizedCollateral;
        uint256 remainCollateral;
        uint256 repaidDebt;
        uint256 surplus;
        uint256 profit;
    }

    /// @dev Transient storage cache for MORPHO address when handling MORPHO callbacks
    address transient _MORPHO;

    /// @dev The address of the Morpho management contract
    IMorphoManagement public immutable MORPHO_MANAGEMENT;

    /**
        @notice Emitted when the liquidator makes a payment to either liquidate or close a position
        @param apm The AccountPositionManager being liquidated or closed
        @param tradeId The unique identifier of the Optimex trade
        @param marketId The identifier for the Morpho market
        @param payer The address that made the payment
        @param isLiquidated True if the position is being liquidated, false if force-closing
        @dev Related function: `payment()`
    */
    event Payment(
        address indexed apm,
        bytes32 indexed tradeId,
        bytes32 marketId,
        address payer,
        bool isLiquidated
    );

    /**
        @notice Emitted when a position is liquidated
        @param apm The AccountPositionManager being liquidated
        @param totalCollateral The total collateral of the position
        @param seizedCollateral The amount of collateral being seized and transferred from the position on Morpho
        @param totalPayment The total amount being paid by the liquidator
        @param repaidDebt The total amount of debt repaid to Morpho by the liquidator
        @dev Related function: `payment()`
    */
    event Liquidate(
        address indexed apm,
        uint256 totalCollateral,
        uint256 seizedCollateral,
        uint256 totalPayment,
        uint256 repaidDebt
    );

    /**
        @notice Emitted when a position is forcibly closed
        @param apm The AccountPositionManager being closed
        @param totalCollateral The total collateral of the position
        @param totalPayment The total amount being paid by the liquidator
        @param repaidDebt The total amount of debt repaid to Morpho by the liquidator
        @dev Related function: `payment()`
    */
    event ForceClose(
        address indexed apm,
        uint256 totalCollateral,
        uint256 totalPayment,
        uint256 repaidDebt
    );

    /**
        @notice Emitted when a surplus amount is credited to the AccountPositionManager
        @param apm The AccountPositionManager being credited
        @param token The token being credited
        @param amount The surplus amount credited
        @dev Related function: `payment()`
    */
    event Credit(
        address indexed apm,
        address indexed token,
        uint256 amount
    );

    /**
        @notice Emitted when profit is taken and transferred after the liquidation
        @param recipient The address receiving the profit (should be `pFeeAddress`)
        @param token The token being taken
        @param amount The amount of tokens taken as profit
        @dev Related function: `payment()`
    */
    event ProfitTaken(
        address indexed recipient,
        address indexed token,
        uint256 amount
    );

    /**
        @notice Emitted when the validator successfully finalize a position
        @param positionId The unique identifier of the Optimex position
        @param apm The AccountPositionManager being finalized and closed
        @param amount The amount of collateral being transferred from the position on Morpho
        @dev Related function: `finalizePosition()`
    */
    event FinalizePosition(
        bytes32 indexed positionId,
        address indexed apm,
        uint256 amount
    );

    /**
        @notice Emitted when Morpho invokes the `onMorphoLiquidate` callback
        @param apm The AccountPositionManager being liquidated
        @param repaidAssets The amount of debt repaid to Morpho
        @param data Additional data for the liquidation callback: (amount, loanToken)
        @dev Related function: `onMorphoLiquidate()`
    */
    event OnMorphoLiquidate(
        address indexed apm,
        uint256 repaidAssets,
        bytes data
    );

    /**
        @notice Emitted when Morpho invokes the `onMorphoRepay` callback
        @param apm The AccountPositionManager being closed
        @param repaidAssets The amount of debt repaid to Morpho
        @param data Additional data for the repayment callback: (amount, loanToken)
        @dev Related function: `onMorphoRepay()`
    */
    event OnMorphoRepay(address indexed apm, uint256 repaidAssets, bytes data);

    modifier onlyMorpho() {
        address sender = msg.sender;
        require(sender == _MORPHO, ErrorLib.Unauthorized(sender));
        _;

        /// Reset transient storage as security recommendation
        /// https://eips.ethereum.org/EIPS/eip-1153#security-considerations
        _MORPHO = address(0);
    }

    constructor(
        address morphoManagement,
        string memory name,
        string memory version
    )
        OptimexDomain(name, version)
        MorphoLiquidatorSigner("MorphoLiquidator Signature Verifier", version)
    {
        require(morphoManagement != address(0), ErrorLib.ZeroAddress());

        MORPHO_MANAGEMENT = IMorphoManagement(morphoManagement);
    }

    /**
        @notice Allows liquidators to make a payment to either liquidate or forcibly close a position
        @param apm The AccountPositionManager being liquidated or closed
        @param tradeId The unique identifier of the Optimex trade
        @param amount The amount paid by the liquidator
        @param isLiquidate True if the position is being liquidated, false if force-closing
        @param signature The validator's signature approving the close operation (ignored if `isLiquidate` is true)
        @dev ⚠️ WARNING ⚠️  
            Only liquidators selected by the Optimex Protocol can redeem locked BTC.  
            Unauthorized liquidators will pay the debt but receive nothing in return,  
            as oBTC has no redeemable value and is transferred back to the ERC-20 contract, 
            effectively removing it from circulation. This may result in permanent loss of funds.
    */
    function payment(
        address apm,
        bytes32 tradeId,
        uint256 amount,
        bool isLiquidate,
        bytes calldata signature
    ) external nonReentrant {
        (
            IMorpho morpho,
            bytes32 marketId,
            Id id,
            address validator,
            MarketParams memory marketParams,
            Position memory position
        ) = _precheck(apm);
        require(amount > 0, ErrorLib.ZeroAmount());

        /// Transfer the payment from the liquidator to this contract
        address sender = msg.sender;
        address loanToken = marketParams.loanToken;
        IERC20(loanToken).safeTransferFrom(sender, address(this), amount);

        /// Accrue the interest and retrieve the position's status from Morpho
        morpho.accrueInterest(marketParams);
        uint256 totalCollateral = position.collateral;
        uint256 borrowShares = position.borrowShares;

        /// Set this contract as the permitted recipient to receive the oBTC token
        /// See documentation for details at `documents/OW_Token.md`
        IOptimexCollateralToken(marketParams.collateralToken).permit(
            address(this)
        );
        PaymentResult memory result;
        _MORPHO = address(morpho); // Cache the Morpho address in transient storage for handling the callback
        bytes memory data = abi.encode(amount, loanToken); // used for callbacks from Morpho during liquidation/repayment

        if (isLiquidate) {
            /// @dev Liquidator repays the user's debt and seizes the collateral.
            /// Leftover collateral, as a proportion of the total collateral, will be calculated and converted to `surplus`
            /// as the `loanToken`, then transferred to the AccountPositionManager.
            /// Any leftover amount after covering debt repayment and surplus is recorded as `profit`.
            result = _liquidate(
                morpho,
                apm,
                id,
                amount,
                totalCollateral,
                borrowShares,
                marketParams,
                data
            );
        } else {
            /// Verify the validator approved the close operation before handling the repayment
            address signer = _getForceCloseSigner(
                apm,
                tradeId,
                signature
            );
            require(signer == validator, ErrorLib.InvalidValidator(signer));

            /// @dev For the repayment, the liquidator must pay the full amount of debt including the accrued interest.
            /// Any leftover amount after covering debt is recorded as `surplus`.
            result = _repay(
                morpho,
                apm,
                amount,
                totalCollateral,
                borrowShares,
                marketParams,
                data
            );
        }

        address collateralToken = marketParams.collateralToken;
        if (result.remainCollateral > 0) {
            if (result.surplus > 0) {
                /// Approve allowance so the surplus can be transferred to the `apm`
                IERC20(loanToken).approval(address(MORPHO_MANAGEMENT), result.surplus);
            }

            /// @dev On liquidation, this contract receives the seized collateral (oBTC).
            /// It must be set as the `permittedRecipient`, which resets after transfer.
            /// Since `remainCollateral` may still be non-zero,
            /// permission must be set again when calling `forceClose()`.
            IOptimexCollateralToken(collateralToken).permit(address(this));
            MORPHO_MANAGEMENT.forceClose(
                apm,
                result.remainCollateral,
                result.surplus,
                marketParams
            );

            emit Credit(apm, loanToken, result.surplus);
        }

        /// @dev The collateral token will be transferred back to the ERC-20 contract, ensuring
        /// all oBTC is removed from circulation. The liquidator will receive
        /// the locked funds through the Optimex Protocol.
        IERC20(collateralToken).safeTransfer(
            address(collateralToken),
            totalCollateral
        );

        emit Payment(apm, tradeId, marketId, sender, isLiquidate);
    }

    /**
        @notice Forcibly withdraws the remaining collateral and finalize a position.
        @dev This function is triggered by the validator when:
          - The loan term of the position has already expired, and
          - The user has already repaid all outstanding debt (`borrowShares = 0`), and
          - The user has not yet withdrawn the collateral (`collateral != 0`),
          which poses risks to the Optimex Protocol.
        @param apm The AccountPositionManager being closed
        @param positionId The unique identifier of the Optimex position
        @param signature The EIP-712 signature from the validator
    */
    function finalizePosition(
        address apm,
        bytes32 positionId,
        bytes calldata signature
    ) external {
        (
            ,
            ,
            ,
            address validator,
            MarketParams memory marketParams,
            Position memory position
        ) = _precheck(apm);
        require(position.borrowShares == 0, ErrorLib.InvalidBorrowShares());

        /// Verify the validator approved the operation before handling further
        address signer = _getFinalizePositionSigner(positionId, apm, signature);
        require(signer == validator, ErrorLib.InvalidValidator(signer));

        /// Set this contract as the permitted recipient to receive the oBTC token
        /// See documentation for details at `documents/OW_Token.md`
        /// Then withdraw the remaining collateral from the position
        /// and transfer it back to the ERC-20 contract to remove it from circulation
        address collateralToken = marketParams.collateralToken;
        IOptimexCollateralToken(collateralToken).permit(address(this));
        uint256 amount = position.collateral;
        MORPHO_MANAGEMENT.forceClose(
            apm,
            amount,
            0,
            marketParams
        );
        IERC20(collateralToken).safeTransfer(collateralToken, amount);

        emit FinalizePosition(positionId, apm, amount);
    }

    /**
        @notice Callback function invoked by Morpho on liquidation
        @param repaidAssets The amount of debt, including accrued interest, being repaid to Morpho
        @param data Additional data used for the liquidation callback including: (amount, loanToken)
    */
    function onMorphoLiquidate(
        uint256 repaidAssets,
        bytes calldata data
    ) external onlyMorpho {
        _handleMorphoCallback(repaidAssets, data);

        emit OnMorphoLiquidate(msg.sender, repaidAssets, data);
    }

    /**
        @notice Callback function invoked by Morpho on repayment
        @param repaidAssets The amount of debt, including accrued interest, being repaid to Morpho
        @param data Additional data used for the repayment callback including: (amount, loanToken)
    */
    function onMorphoRepay(
        uint256 repaidAssets,
        bytes calldata data
    ) external onlyMorpho {
        _handleMorphoCallback(repaidAssets, data);

        emit OnMorphoRepay(msg.sender, repaidAssets, data);
    }

    function _handleMorphoCallback(
        uint256 repaidAssets,
        bytes calldata data
    ) private {
        (uint256 amount, address loanToken) = abi.decode(
            data,
            (uint256, address)
        );
        require(amount >= repaidAssets, ErrorLib.InvalidAmount());

        /// Approve the allowance so the loan token can be transferred to Morpho
        /// Note: msg.sender == _MORPHO
        IERC20(loanToken).approval(msg.sender, repaidAssets);
    }

    function _precheck(
        address apm
    )
        internal
        view
        returns (
            IMorpho morpho,
            bytes32 marketId,
            Id id,
            address validator,
            MarketParams memory marketParams,
            Position memory position
        )
    {
        // MORPHO_MANAGEMENT.validateAPM(apm);
        marketId = MORPHO_MANAGEMENT.apmMarkets(apm);
        id = Id.wrap(marketId);
        (address morpho_, address oBTC, address validator_) = MORPHO_MANAGEMENT
            .getAPMConfigurations(apm);
        morpho = IMorpho(morpho_);
        validator = validator_;
        marketParams = morpho.idToMarketParams(id);
        position = morpho.position(id, apm);
        require(marketId != bytes32(0), ErrorLib.InvalidAPM());
        require(
            marketParams.collateralToken == oBTC,
            ErrorLib.TokenMismatch(oBTC, marketParams.collateralToken)
        );
    }

    function _liquidate(
        IMorpho morpho,
        address apm,
        Id marketId,
        uint256 amount,
        uint256 totalCollateral,
        uint256 borrowShares,
        MarketParams memory marketParams,
        bytes memory data
    ) private returns (PaymentResult memory result) {
        Market memory market = morpho.market(marketId);

        /// Estimate the collateral being seized from the position
        uint256 seizedCollateral = _estimateSeizedCollateral(
            borrowShares,
            marketParams,
            market
        );

        if (seizedCollateral < totalCollateral) {
            /// @dev In a normal liquidation, `seizedCollateral` and `repaidDebt` are calculated based on `borrowShares`.
            /// The condition `amount >= repaidDebt` is already verified in `_handleMorphoCallback`.
            (result.seizedCollateral, result.repaidDebt) = morpho.liquidate(
                marketParams,
                apm,
                0,
                borrowShares,
                data
            );
            result.remainCollateral = totalCollateral - result.seizedCollateral;

            /// @dev The user's `surplus` (in loan tokens) is the minimum of:
            ///   - `remainder`: the user’s proportional share of the remaining collateral, valued in loan tokens.
            ///   - `excessPayment`: the portion of the liquidator’s payment left after repaying the debt.
            uint256 remainder = (amount * result.remainCollateral) /
                totalCollateral;
            uint256 excessPayment = amount - result.repaidDebt;
            result.surplus = excessPayment < remainder
                ? excessPayment
                : remainder;

            /// Protocol profit is the remaining amount after covering debt and surplus
            result.profit = amount - (result.repaidDebt + result.surplus);
        } else {
            /// @dev For a bad debt, the `seizedCollateral` and `repaidDebt` are calculated using the `totalCollateral`.
            /// The `surplus` is set to `0`.
            /// Any leftover amount after covering debt is recorded as `profit`.
            (result.seizedCollateral, result.repaidDebt) = morpho.liquidate(
                marketParams,
                apm,
                totalCollateral,
                0,
                data
            );
            result.profit = amount - result.repaidDebt;
        }

        /// Transfer the `profit` to the Optimex Protocol fee receiver.
        /// This profit will be accounted for and distributed to the liquidator later.
        if (result.profit > 0) {
            address pFeeAddress = MORPHO_MANAGEMENT.getPFeeAddress();
            require(pFeeAddress != address(0), ErrorLib.ZeroAddress());

            IERC20(marketParams.loanToken).safeTransfer(
                pFeeAddress,
                result.profit
            );

            emit ProfitTaken(
                pFeeAddress,
                marketParams.loanToken,
                result.profit
            );
        }

        emit Liquidate(
            apm,
            totalCollateral,
            result.seizedCollateral,
            amount,
            result.repaidDebt
        );
    }

    function _repay(
        IMorpho morpho,
        address apm,
        uint256 amount,
        uint256 totalCollateral,
        uint256 borrowShares,
        MarketParams memory marketParams,
        bytes memory data
    ) private returns (PaymentResult memory result) {
        /// @dev This is a repayment to forcibly close a position. Therefore, the protocol won't take any profit.
        /// The `repaidDebt` is calculated and returned by Morpho using the `borrowShares`.
        /// Any leftover amount after covering debt is recorded as `surplus`.
        (result.repaidDebt, ) = morpho.repay(
            marketParams,
            0,
            borrowShares,
            apm,
            data
        );
        result.surplus = amount - result.repaidDebt;
        result.remainCollateral = totalCollateral;

        emit ForceClose(apm, totalCollateral, amount, result.repaidDebt);
    }

    /// @notice Calculates the amount of collateral that will be seized for the given `borrowShares`
    /// @return seizedCollateral The estimated amount of collateral that will be seized from the position
    function _estimateSeizedCollateral(
        uint256 borrowShares,
        MarketParams memory marketParams,
        Market memory market
    ) private view returns (uint256 seizedCollateral) {
        /// Computes the liquidation incentive factor.
        ///
        /// The factor is bounded by `MAX_LIQUIDATION_INCENTIVE_FACTOR` and depends on
        /// the market's loan-to-value (LLTV) parameter, adjusted by `LIQUIDATION_CURSOR`.
        ///
        /// @dev Logic adapted from Morpho:
        /// https://github.com/morpho-org/morpho-blue/blob/2a98681bff263de8bcfb93e7b043884c5195652e/src/Morpho.sol#L366
        uint256 liquidationIncentiveFactor = UtilsLib.min(
            MAX_LIQUIDATION_INCENTIVE_FACTOR,
            WAD.wDivDown(
                WAD - LIQUIDATION_CURSOR.wMulDown(WAD - marketParams.lltv)
            )
        );

        /// Calculates the amount of collateral that can be seized during liquidation:
        ///
        ///   seizedCollateral = borrowShares
        ///      * (totalBorrowAssets / totalBorrowShares)
        ///      * liquidationIncentiveFactor
        ///      * (ORACLE_PRICE_SCALE / collateralPrice)
        ///
        /// where:
        /// - (totalBorrowAssets / totalBorrowShares) converts `borrowShares` to the underlying borrow assets
        /// - liquidationIncentiveFactor applies the liquidation bonus (≤ MAX_LIQUIDATION_INCENTIVE_FACTOR)
        /// - (ORACLE_PRICE_SCALE / collateralPrice) normalizes the oracle price, converting borrow assets to collateral units
        ///
        /// @dev Formula adapted from Morpho:
        /// https://github.com/morpho-org/morpho-blue/blob/2a98681bff263de8bcfb93e7b043884c5195652e/src/Morpho.sol#L378
        uint256 collateralPrice = IOracle(marketParams.oracle).price();
        seizedCollateral = borrowShares
            .toAssetsDown(market.totalBorrowAssets, market.totalBorrowShares)
            .wMulDown(liquidationIncentiveFactor)
            .mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
    }
}
