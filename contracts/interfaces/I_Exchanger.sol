pragma solidity ^0.4.17;

interface ExchangerI {
    /* Order creation */
    function buyTokens(address _recipient) payable public;
    function sellTokens(address _recipient, uint256 tokensCount) public;

    /* Rate calc & init  params */
    function requestRates() payable public;
    function calcRates() public;

    /* Data getters */
    function tokenBalance() public view returns(uint256);
    function getOracleData(uint number) public view returns (bytes32, bytes32, bool, uint256, uint256, uint256);
    function balanceOf(address _owner) view public returns(uint256);

    /* Balance methods */
    function claimBalance() public;
    function refillBalance() payable public;
    function withdrawReserve() public;
}