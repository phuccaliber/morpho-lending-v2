// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@morpho-blue/interfaces/IOracle.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/interfaces/IMorpho.sol";
import "lib/metamorpho-v1.1/lib/morpho-blue/src/libraries/MarketParamsLib.sol";

import "contracts/tokens/OptimexBTC.sol";
import "contracts/protocol/OptimexProtocol.sol";
import "contracts/MorphoManagement.sol";
import "../foundry/common/BaseTest.t.sol";

contract BaseMainnetTest is BaseTest {
    using MarketParamsLib for MarketParams;

    /// USDC minter official address on ETH
    address internal USDC_MINTER =
        address(0x5B6122C109B78C6755486966148C1D70a50A47D7);

    function setUp() public virtual override(BaseTest) {
        // USDC official address
        LOAN_TOKEN = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        /// Morpho official address on ETH
        MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
        /// IRM official address on ETH
        IRM = address(0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC);
        /// BTC/USD oracle address on ETH
        ORACLE = address(0xA6D6950c9F177F1De7f7757FB33539e3Ec60182a);
        /// Optimex Protocol official address on ETH
        OPTIMEX_PROTOCOL = OptimexProtocol(
            0xE7f59E0D589142dFa1B7cC1F160e0015a5fE57c6
        );
        OWNER = OPTIMEX_PROTOCOL.owner();

        vm.startPrank(USDC_MINTER);
        /// MINT 1M USDC to SUPPLIER
        (bool success, ) = address(LOAN_TOKEN).call(
            abi.encodeWithSignature(
                "mint(address,uint256)",
                SUPPLIER,
                1000000e6
            )
        );
        assertEq(success, true, "Mint failed");

        /// MINT 1M USDC to LIQUIDATOR
        (bool success2, ) = address(LOAN_TOKEN).call(
            abi.encodeWithSignature(
                "mint(address,uint256)",
                LIQUIDATOR,
                1000000e6
            )
        );
        assertEq(success2, true, "Mint failed");

        vm.stopPrank();

        _setOraclePrice(100000e34);

        BaseTest.setUp();
        /// Setup Optimex Protocol
    }

    function test_USDCInit() public {
        assertNotEq(marketId, bytes32(0), "Market ID is not set");
    }
}
