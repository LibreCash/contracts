pragma solidity ^0.4.17;

import "../zeppelin/token/StandardToken.sol";


contract LibertyToken is StandardToken {
    string public name = "LibreBank";
    string public symbol = "LBRS";
    uint256 public decimals = 18;

    function LibertyToken() public {
        totalSupply_ = 100 * (10**6) * (10**decimals);
        balances[msg.sender] = totalSupply_;
    }
}   