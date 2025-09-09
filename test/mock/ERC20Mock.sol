// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 tokenDecimals) ERC20(name, symbol) {
        _decimals = tokenDecimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
