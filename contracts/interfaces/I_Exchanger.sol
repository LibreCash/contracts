pragma solidity ^0.4.23;

interface ExchangerI {
    /* Order creation */
    function buyTokens(address _recipient) payable public;
    function sellTokens(address _recipient, uint256 tokensCount) public;

    /* Data getters */
    function tokenBalance() public view returns(uint256);

    /* Balance methods */
    function refillBalance() payable public;
    function withdrawReserve() public;
}
