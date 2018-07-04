pragma solidity ^0.4.23;

import "./token/LibertyToken.sol";
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';


contract LBRSMultitransfer is Ownable {
    address public lbrsToken;
    address public sender;
    LibertyToken token;

    /**
     * @dev Implements transfer method for multiple recipient. Needed in LBRS token distribution process after ICO
     * @param recipient - recipient addresses array
     * @param balance - refill amounts array
     */
    function multiTransfer(address[] recipient,uint256[] balance) public {
        require(recipient.length == balance.length && msg.sender == sender);

        for (uint256 i = 0; i < recipient.length; i++) {
            token.transfer(recipient[i],balance[i]);
        }
    }

    /**
     * @dev Constructor
     * @param LBRS - LBRS token address
     */
    constructor (address LBRS, address _sender) public {
        lbrsToken = LBRS;
        sender = _sender;
        token = LibertyToken(lbrsToken);
    }

    /**
     * @dev Withdraw unsold tokens
     */
    function withdrawTokens() public onlyOwner {
        token.transfer(owner,tokenBalance());
    }

    /**
     * @dev Returns LBRS token balance of contract.
     */
    function tokenBalance() public view returns(uint256) {
        return token.balanceOf(this);
    }

     /**
     * @dev Sets new token sender address
     * @param _sender - token sender addresses
     */
    function setSender(address _sender) public onlyOwner {
        sender = _sender;
    }
}
