pragma solidity ^0.4.17;

import "../zeppelin/token/MintableToken.sol";
import "../zeppelin/token/BurnableToken.sol";


/**
 * @title LibreCash token contract.
 *
 * @dev ERC20 token contract.
 */
contract LibreCash is MintableToken, BurnableToken {
    string public constant name = "LibreCash";
    string public constant symbol = "Libre";
    uint32 public constant decimals = 18;
}