// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PrivateGardenToken is ERC20 {
    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {
        _mint(msg.sender, 10000000 * 10**18);
    }

    function mint(address account, uint amount) public {
        require(account != address(0), "");
        require(amount > 0 , "");

        _mint(account, amount);
    }
}
