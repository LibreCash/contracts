pragma solidity ^0.4.23;

import 'openzeppelin-solidity/contracts/token/ERC20/StandardBurnableToken.sol';


contract LibertyToken is StandardBurnableToken {
   string public name = "LibreBank";
   string public symbol = "LBRS";
   uint256 public decimals = 18;

   constructor() public {
     totalSupply_ = 100 * (10**6) * (10**decimals);
     balances[msg.sender] = totalSupply_;
   }
}
