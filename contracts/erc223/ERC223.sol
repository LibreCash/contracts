pragma solidity ^0.4.11;

/**
 * @title ERC223 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC223 {
  function allowance(address owner, address spender) constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) returns (bool);
  function approve(address spender, uint256 value) returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
