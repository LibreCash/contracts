pragma solidity ^0.4.18;

import "../zeppelin/token/MintableToken.sol";
import "../zeppelin/token/BurnableToken.sol";
import "../zeppelin/ownership/Claimable.sol";



/**
 * @title LibreCash token contract.
 *
 * @dev ERC20 token contract.
 */
contract LibreCash is MintableToken, BurnableToken, Claimable  {
    string public constant name = "LibreCash";
    string public constant symbol = "Libre";
    uint32 public constant decimals = 18;
}