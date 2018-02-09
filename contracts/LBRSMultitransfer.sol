pragma solidity ^0.4.17;

import "./token/LibertyToken.sol"; 
import "./zeppelin/ownership/Ownable.sol";

contract LBRSMultitransfer is Ownable {
    address public lbrsToken;
    LibertyToken token;

    /**
     * @dev Implements transfer method for multiple recipient. Needed in LBRS token distribution process after ICO
     * @param recipient - recipient addresses array
     * @param balance - refill amounts array
     */
    function multiTransfer(address[] recipient,uint256[] balance) public onlyOwner {
        require(recipient.length == balance.length);
        
        for(uint256 i = 0; i < recipient.length; i++) {
            token.transfer(recipient[i],balance[i]);
        }
    }

    /**
     * @dev Constructor
     * @param LBRS - LBRS token address
     */
    function LBRSMultitransfer(address LBRS) public {
        lbrsToken = LBRS;
        token = LibertyToken(lbrsToken);
    }

    /**
     * @dev Returns LBRS token balance of contract.
     */
    function tokenBalance() public returns(uint256) {
        return token.balanceOf(this);
    }
}