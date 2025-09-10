// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@morpho-blue/interfaces/IMorpho.sol";
import "@morpho-blue/libraries/MarketParamsLib.sol";
import "./protocol/OptimexAdminGuard.sol";
import "./protocol/OptimexDomain.sol";
import "./utils/MorphoManagementSigner.sol";
import "./libraries/TokenUtils.sol";
import "./interfaces/IMorphoManagement.sol";

contract MorphoManagement is
    OptimexAdminGuard,
    OptimexDomain,
    MorphoManagementSigner,
    IMorphoManagement
{
    using MarketParamsLib for MarketParams;
    using SafeERC20 for IERC20;
    using TokenUtils for IERC20;

    /// keccak256("VALIDATOR_ROLE");
    bytes32 private constant _VALIDATOR_ROLE =
        0x21702c8af46127c7fa207f89d0b0a8441bb32959a0ac7df790e9ab1a25c98926;
    /// keccak256("WALLET_DELEGATOR_ROLE");
    bytes32 private constant _WALLET_DELEGATOR_ROLE =
        0x98f541bbc60e0985b6b2060b59d90fe89e3caed07b79214afd8d7dbfbe5691ac;

    /// @dev The address of the Morpho contract
    address public immutable MORPHO;

    /// @dev The address of the OptimexBTC token
    address public immutable OBTC;

    /// @dev Tracks validator of each AccountPositionManager
    mapping(address => address) public apmValidators;

    /// @dev Tracks authorizer of each AccountPositionManager
    mapping(address => address) public apmAuthorizers;

    /// @dev Tracks the market of each apm
    /// Each APM is associated with a single market on Morpho
    mapping(address => bytes32) public apmMarkets;

    /// @dev Mapping that stores the action counter for each apm
    /// This counter is used as a nonce to prevent signature replay attacks
    /// It is incremented when some authorized actions are performed for each position, including:
    ///   - Borrow
    ///   - Withdraw
    ///   - Claim
    mapping(address => uint256) public actionCounters;

    /// @dev Mapping that stores the loan counter for each position
    /// This counter is used as a nonce to prevent signature replay attacks, and
    /// tracks the number of loan supply requests
    /// It is incremented when `supply` is called for a new loan request
    mapping(address => uint256) public loanCounters;

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

    modifier checkValidator(address validator) {
        require(_isValidator(validator), ErrorLib.InvalidValidator(validator));
        _;
    }

    constructor(
        IOptimexProtocol initProtocol,
        address morpho,
        address oBTC,
        string memory name,
        string memory version
    )
        OptimexAdminGuard(initProtocol)
        OptimexDomain(name, version)
        MorphoManagementSigner("MorphoManagement signature verifier", version)
    {
        require(
            morpho != address(0) && oBTC != address(0),
            ErrorLib.ZeroAddress()
        );
        MORPHO = morpho;
        OBTC = oBTC;
    }

    /**
        @notice Creates a new AccountPositionManager with address `apm`
        @param apm The newly AccountPositionManager address
        @param authorizer The authorizer assigned to the AccountPositionManager
        @param validator The validator assigned to the AccountPositionManager
        @param deadline The deadline of the signature
        @param morphoSetAuthSig The signature signed by the apm key, performed by WalletDelegator
        @param walletDelegatorSig The signature signed by the wallet delegator key,
        @dev `walletDelegatorSig` ensures the APM is generated and used once by WalletDelegator
    */
    function createAPM(
        address apm,
        address authorizer,
        address validator,
        uint256 deadline,
        bytes calldata morphoSetAuthSig,
        bytes calldata walletDelegatorSig
    ) external checkValidator(validator) {
        /// Ensure the following conditions are met:
        /// - Validator is valid by checking on the modifier
        /// - APM and authorizer is not zero address
        /// - APM is not created
        require(
            apm != address(0) && authorizer != address(0),
            ErrorLib.ZeroAddress()
        );
        require(apmValidators[apm] == address(0), ErrorLib.InvalidAPM());
        address signer = _getDelegatorSigner(apm, deadline, walletDelegatorSig);
        require(_isDelegator(signer), ErrorLib.InvalidDelegator(signer));

        apmValidators[apm] = validator;
        apmAuthorizers[apm] = authorizer;

        /// Message to be signed by the apm, allows address(this) control the apm
        Authorization memory authorization = Authorization({
            authorizer: apm,
            authorized: address(this),
            isAuthorized: true,
            nonce: 0,
            deadline: deadline
        });

        Signature memory signature = Signature({
            r: bytes32(morphoSetAuthSig[0:32]),
            s: bytes32(morphoSetAuthSig[32:64]),
            v: uint8(morphoSetAuthSig[64])
        });

        /// @dev Set the authorization of the APM to address(this)
        /// Allow address(this) to perform borrow/withdraw on behalf of the apm
        IMorpho(MORPHO).setAuthorizationWithSig(authorization, signature);

        emit APMCreated(apm, authorizer, validator);
    }

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
    ) external {
        /// Ensure the following conditions are met:
        /// - APM is valid, by checking the authorizer is not zero address
        /// - Assets is greater than 0
        /// - marketParams is valid
        /// - The signature for supplying collateral is signed by the authorizer
        address authorizer = apmAuthorizers[apm];
        require(authorizer != address(0), ErrorLib.InvalidAPM());
        require(assets > 0, ErrorLib.ZeroAmount());
        bytes32 marketId = _validateMarketId(marketParams, apm);
        uint256 loanCounter = loanCounters[apm];
        require(
            _verifySupplySig(
                authorizer,
                apm,
                marketId,
                assets,
                loanCounter,
                sig
            ),
            ErrorLib.InvalidAuthorizerSig()
        );

        apmMarkets[apm] = marketId;
        loanCounters[apm] = loanCounter + 1;

        IERC20(marketParams.collateralToken).approve(address(MORPHO), assets);
        IMorpho(MORPHO).supplyCollateral(marketParams, assets, apm, "");

        emit Supplied(apm, marketId, assets, loanCounter);
    }

    /**
        @notice Queries the address set as the protocol fee receiver
        @return The address set as the protocol fee receiver
    */
    function getPFeeAddress() external view returns (address) {
        return _protocol.pFeeAddr();
    }

    /**
        @notice Queries the configurations for a specified `apm`
        @param apm The AccountPositionManager to query
        @return morpho The address of the Morpho contract
        @return oBTC The address of the OptimexBTC token
        @return validator The validator address assigned to this `apm`
    */
    function getAPMConfigurations(
        address apm
    ) external view returns (address morpho, address oBTC, address validator) {
        morpho = MORPHO;
        oBTC = OBTC;
        validator = apmValidators[apm];
    }

    /**
        @notice Checks if the provided `account` has been granted the `role`
        @param role The role to check
        @param account The address to check
        @return True if the address has been granted the role, false otherwise
    */
    function isAuthorized(
        bytes32 role,
        address account
    ) external view returns (bool) {
        return _isAuthorized(role, account);
    }

    function _isValidator(address validator) private view returns (bool) {
        return _isAuthorized(_VALIDATOR_ROLE, validator);
    }

    function _isDelegator(address delegator) private view returns (bool) {
        return _isAuthorized(_WALLET_DELEGATOR_ROLE, delegator);
    }

    function _validateMarketId(
        MarketParams calldata marketParams,
        address apm
    ) private returns (bytes32) {
        bytes32 id = Id.unwrap(marketParams.id());
        bytes32 marketId = apmMarkets[apm];
        if (marketId == bytes32(0)) {
            apmMarkets[apm] = id;
        } else {
            require(id == marketId, ErrorLib.MarketMismatch(marketId, id));
        }
        return id;
    }
}
