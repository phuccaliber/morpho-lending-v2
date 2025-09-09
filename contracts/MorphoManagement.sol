// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./protocol/OptimexAdminGuard.sol";
import "./protocol/OptimexDomain.sol";

contract MorphoManagement is OptimexAdminGuard, OptimexDomain {
    /// keccak256("VALIDATOR_ROLE");
    bytes32 private constant _VALIDATOR_ROLE =
        0x21702c8af46127c7fa207f89d0b0a8441bb32959a0ac7df790e9ab1a25c98926;

    /// @dev The address of the Morpho contract
    address public immutable MORPHO;

    /// @dev The address of the OptimexBTC token
    address public immutable OBTC;

    /// @dev Tracks validator of each AccountPositionManager
    mapping(address => address) public apmValidators;

    /// @dev Tracks authorizer of each AccountPositionManager
    mapping(address => address) public apmAuthorizers;

    event APMCreated(
        address indexed apm,
        address indexed authorizer,
        address indexed validator
    );

    modifier checkValidator(address validator) {
        require(_isValidator(validator), ErrorLib.InvalidValidator(validator));
        _;
    }

    constructor(
        IOptimexProtocol initProtocol,
        string memory name,
        string memory version
    ) OptimexAdminGuard(initProtocol) OptimexDomain(name, version) {}

    /**
        @notice Creates a new AccountPositionManager with address `apm`
        @param apm The newly AccountPositionManager address
        @param authorizer The authorizer assigned to the AccountPositionManager
        @param validator The validator assigned to the AccountPositionManager
        @dev TODO: Validate validator and authorizer are passed in correctly
    */
    function createAPM(
        address apm,
        address authorizer,
        address validator
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

        apmValidators[apm] = validator;
        apmAuthorizers[apm] = authorizer;

        emit APMCreated(apm, authorizer, validator);
    }

    function _isValidator(address validator) private view returns (bool) {
        return _isAuthorized(_VALIDATOR_ROLE, validator);
    }
}
