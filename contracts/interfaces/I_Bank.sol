pragma solidity ^0.4.23;

interface BankI {
    /* Order creation && cancelation */
    function buyTokens(address _recipient) payable public;
    function sellTokens(address _recipient, uint256 _tokensCount) public;

    /* Constant setters */
    function attachToken(address _tokenAddress) public;

    /* Tokens admin methods */
    function transferTokenOwner(address newOwner) public;
    function claimOwnership() public;
}
