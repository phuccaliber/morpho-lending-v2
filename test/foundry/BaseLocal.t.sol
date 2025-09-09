// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "lib/metamorpho-v1.1/lib/morpho-blue/src/interfaces/IMorpho.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import "lib/metamorpho-v1.1/src/mocks/IRMMock.sol";
import "lib/metamorpho-v1.1/src/mocks/OracleMock.sol";

import "contracts/protocol/OptimexProtocol.sol";
import "contracts/tokens/OptimexBTC.sol";
import "contracts/interfaces/IOptimexProtocol.sol";

import "../foundry/common/BaseTest.t.sol";
import "../mock/ERC20Mock.sol";

contract BaseLocalTest is BaseTest {
    using MarketParamsLib for MarketParams;

    function setUp() public virtual override(BaseTest) {
        /// The morpho.json file is generated when running `yarn test:local`
        /// It stores the addresses of the deployed contracts on local network
        string memory path = string.concat(
            vm.projectRoot(),
            "/deployments/morpho.json"
        );
        string memory json = vm.readFile(path);

        // Setup addresses
        /// Read owner address from morpho.json
        OWNER = vm.parseJsonAddress(json, ".owner");
        /// Read Deployed Morpho address from morpho.json
        address morphoAddress = vm.parseJsonAddress(json, ".address");
        MORPHO = IMorpho(morphoAddress);
        vm.startPrank(OWNER);

        /// Deploy mock USDC
        LOAN_TOKEN = address(new ERC20Mock("USDC", "USDC", 6));
        /// MINT 1M USDC to SUPPLIER and LIQUIDATOR
        ERC20Mock(LOAN_TOKEN).mint(SUPPLIER, 1000000e6);
        ERC20Mock(LOAN_TOKEN).mint(LIQUIDATOR, 100000e6);

        /// Initialize mock IRM and Oracle
        IRM = address(new IrmMock());
        ORACLE = address(new OracleMock());
        MORPHO.enableIrm(address(IRM));
        MORPHO.enableLltv(86e16);

        OPTIMEX_PROTOCOL = new OptimexProtocol(
            0,
            OWNER,
            P_FEE_ADDRESS,
            "Optimex",
            "Version 1"
        );

        vm.stopPrank();

        _setOraclePrice(100000e34);

        BaseTest.setUp();
    }
}
