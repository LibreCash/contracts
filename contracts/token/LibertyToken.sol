pragma solidity ^0.4.17;

import "../zeppelin/token/StandardToken.sol";
import "../zeppelin/ownership/Ownable.sol";


contract LibertyToken is StandardToken, Ownable {
    string public name = "Liberty Token";
    string public symbol = "LBT";
    uint256 public decimals = 18;

    function LibertyToken() public {
        totalSupply = 100 * (10**6) * (10**decimals);
        balances[msg.sender] = totalSupply;
    }
}