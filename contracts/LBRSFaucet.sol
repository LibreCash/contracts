pragma solidity ^0.4.18;

import "./token/LibertyToken.sol"; 
import "./zeppelin/ownership/Ownable.sol";

contract LBRSFaucet is Ownable {
    address public lbrsToken;
    LibertyToken token;
    uint256 public tokensToSend = 2000 * 10**(token.decimals());
    mapping(address => bool) tokensSent;

    /**
     * @dev Constructor
     * @param LBRS - LBRS token address
     */
    function LBRSFaucet(address LBRS) public {
        lbrsToken = LBRS;
        token = LibertyToken(lbrsToken);
        
    }

    
    /**
     * @dev Returns LBRS token balance of contract.
     */
    function tokenBalance() public view returns(uint256) {
        return token.balanceOf(this);
    }


    /**
     * @dev Implements method for getting testing LBRS tokens to DAO testing.
     */
    function get() public {
        require(!tokensSent[msg.sender]);
        tokensSent[msg.sender] = true;
        token.transfer(msg.sender, tokensToSend);
    }

    /**
     * @dev Sets tokens amount to send
     */
    function setTokenAmount(uint256 tokensAmount) public onlyOwner {
        tokensToSend = tokensAmount * 10**(token.decimals());
    }

}    