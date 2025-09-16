// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestERC20 is ERC20, Ownable {
    uint8 private _decimals;

    constructor() ERC20("test", "tst") Ownable(msg.sender) {
        _decimals = 18;
        _mint(msg.sender, 1000 * 10 ** 18);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function faucet(uint256 amount) external {
        _mint(msg.sender, amount * 10 ** _decimals);
    }
}
