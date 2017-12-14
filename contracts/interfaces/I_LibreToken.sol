pragma solidity ^0.4.11;

contract LibreTokenI {
    uint public totalSupply;
    function balanceOf(address _owner) public returns (uint256);
    function mint(address _to, uint256 _amount) public;
    function burn(address _burner, uint256 _value) public;
    function setBankAddress(address _bankAddress) public;
}