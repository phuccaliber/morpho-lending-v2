// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/metamorpho-v1.1/src/mocks/OracleMock.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/interfaces/IOracle.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/interfaces/IMorpho.sol";
import "contracts/tokens/OptimexBTC.sol";
import "contracts/protocol/OptimexProtocol.sol";

import "contracts/MorphoManagement.sol";
import "contracts/MorphoSupplier.sol";
import "./Utils.t.sol";

contract BaseTest is Test, Utils {
    using MarketParamsLib for MarketParams;

    uint256 public constant BORROWER_PRIVATE_KEY =
        uint256(keccak256("BORROWER_KEY"));
    uint256 public constant AUTHORIZER_PRIVATE_KEY =
        uint256(keccak256("AUTHORIZER_KEY"));
    uint256 public constant VALIDATOR_PRIVATE_KEY =
        uint256(keccak256("MPC_KEY"));
    uint256 internal constant APM_PRIVATE_KEY = uint256(keccak256("APM_KEY"));
    uint256 internal constant DELEGATOR_PRIVATE_KEY =
        uint256(keccak256("DELEGATOR_KEY"));

    OptimexBTC internal BTC;
    address internal LOAN_TOKEN;
    OptimexProtocol internal OPTIMEX_PROTOCOL;
    MorphoManagement internal MORPHO_MANAGEMENT;
    MorphoSupplier internal MORPHO_SUPPLIER;

    IMorpho internal MORPHO;
    address internal ORACLE;
    address internal IRM;
    MarketParams internal marketParams;
    Id internal id;
    bytes32 internal marketId;

    address internal OWNER;
    address internal SUPPLIER = makeAddr("SUPPLIER");
    address internal LIQUIDATOR = makeAddr("LIQUIDATOR");
    address internal BORROWER = vm.addr(BORROWER_PRIVATE_KEY);
    address internal VALIDATOR = vm.addr(VALIDATOR_PRIVATE_KEY);
    address internal AUTHORIZER = vm.addr(AUTHORIZER_PRIVATE_KEY);
    address internal APM = vm.addr(APM_PRIVATE_KEY);
    address internal P_FEE_ADDRESS = makeAddr("P_FEE_ADDRESS");
    address internal DELEGATOR = vm.addr(DELEGATOR_PRIVATE_KEY);
    string internal constant BITCOIN_PUBKEY = "BITCOIN_PUBKEY";
    bytes32 internal constant POSITION_ID = keccak256("POSITION_ID");

    function setUp() public virtual {
        vm.startPrank(OWNER);
        BTC = new OptimexBTC(5e8, address(OPTIMEX_PROTOCOL));

        MORPHO_MANAGEMENT = new MorphoManagement(
            IOptimexProtocol(address(OPTIMEX_PROTOCOL)),
            address(MORPHO),
            address(BTC),
            "ethereum:MorphoManagement",
            "version 1"
        );
        MORPHO_SUPPLIER = new MorphoSupplier(
            address(MORPHO_MANAGEMENT),
            "ethereum:MorphoSupplier",
            "version 1"
        );

        marketParams = MarketParams({
            loanToken: address(LOAN_TOKEN),
            collateralToken: address(BTC),
            oracle: address(ORACLE),
            irm: address(IRM),
            lltv: 86e16
        });
        MORPHO.createMarket(marketParams);
        id = marketParams.id();
        marketId = Id.unwrap(id);

        OPTIMEX_PROTOCOL.grantRole(
            keccak256("VALIDATOR_ROLE"),
            address(VALIDATOR)
        );
        OPTIMEX_PROTOCOL.grantRole(
            keccak256("OBTC_ALLOCATOR_ROLE"),
            address(MORPHO_SUPPLIER)
        );
        OPTIMEX_PROTOCOL.grantRole(
            keccak256("OBTC_RECIPIENT_CONTROLLER_ROLE"),
            address(MORPHO_SUPPLIER)
        );
        OPTIMEX_PROTOCOL.grantRole(
            keccak256("WALLET_DELEGATOR_ROLE"),
            address(DELEGATOR)
        );
        vm.stopPrank();

        vm.startPrank(SUPPLIER);
        IERC20(LOAN_TOKEN).approve(address(MORPHO), type(uint256).max);
        MORPHO.supply(marketParams, 1000000e6, 0, SUPPLIER, "");
        vm.stopPrank();

        vm.startPrank(AUTHORIZER);
        uint256 deadline = block.timestamp + 1000;
        Authorization memory authorization = Authorization({
            authorizer: APM,
            authorized: address(MORPHO_MANAGEMENT),
            isAuthorized: true,
            nonce: 0,
            deadline: deadline
        });

        bytes memory signature = _signMorphoSetAuthorizer(
            APM_PRIVATE_KEY,
            authorization,
            address(MORPHO)
        );

        bytes memory walletDelegatorSig = _signAPMGenerated(
            DELEGATOR_PRIVATE_KEY,
            APM,
            deadline,
            address(MORPHO_MANAGEMENT)
        );

        MORPHO_MANAGEMENT.createAPM(
            APM,
            AUTHORIZER,
            VALIDATOR,
            deadline,
            signature,
            walletDelegatorSig
        );

        vm.stopPrank();
    }

    function _setOraclePrice(uint256 price) internal {
        string memory profile = vm.envString("PROFILE");
        if (keccak256(bytes(profile)) == keccak256(bytes("mainnet"))) {
            vm.mockCall(
                address(ORACLE),
                abi.encodeWithSelector(IOracle.price.selector),
                abi.encode(price)
            );
        } else if (keccak256(bytes(profile)) == keccak256(bytes("local"))) {
            vm.prank(OWNER);
            OracleMock(ORACLE).setPrice(price);
        } else {
            revert("Invalid profile");
        }
    }
}
