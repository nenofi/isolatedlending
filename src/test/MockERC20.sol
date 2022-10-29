// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.4;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "solmate/tokens/ERC20.sol";


contract MockERC20 is ERC20{
    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals){
    }

    function mint(uint256 _amount) public{
        _mint(msg.sender, _amount);
    }

    function burn(uint256 _amount) public{
        _burn(msg.sender, _amount);
    }

}