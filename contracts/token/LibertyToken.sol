pragma solidity ^0.4.18;

import "../zeppelin/token/StandardToken.sol";
import "../zeppelin/token/BurnableToken.sol";

contract LibertyToken is StandardToken, BurnableToken {
    string public name = "LibreBank";
    string public symbol = "LBRS";
    uint256 public decimals = 18;

    function LibertyToken() public {
        totalSupply_ = 100 * (10**6) * (10**decimals);
        balances[msg.sender] = totalSupply_;
    }
} 