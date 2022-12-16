pragma solidity >= 0.8.4;

interface IBeefyVault{
    function balanceOf(address account) external view returns (uint256);
    function deposit(uint256 amount) external;
    function _mint(uint256 amount) external;
}