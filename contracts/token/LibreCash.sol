pragma solidity ^0.4.17;

import "../zeppelin/token/MintableToken.sol";
import "../zeppelin/token/BurnableToken.sol";


/**
 * @title LibreCash token contract.
 *
 * @dev ERC20 token contract.
 */
contract LibreCash is MintableToken, BurnableToken {
    string public constant name = "LibreCash Token";
    string public constant symbol = "LCT";
    uint32 public constant decimals = 18;

    /**
    * @dev Reject all ERC23 compatible tokens
    * @param from_ The address that is transferring the tokens
    * @param value_ the amount of the specified token
    * @param data_ The data passed from the caller.
    */
    function tokenFallback(address from_, uint256 value_, bytes data_) external {
        revert();
    }
}