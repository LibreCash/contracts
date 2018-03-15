pragma solidity ^0.4.18;

interface BankI {
    /* Order creation && cancelation */
    function buyTokens(address _recipient) payable public;
    function sellTokens(address _recipient, uint256 _tokensCount) public;

    /* Rate calc & init  params */
    function calcRates() public;
    function requestRates() payable public;
    
    /* Data getters */
    function readyOracles() public view returns (uint256);
    function waitingOracles() public view returns (uint256);
    function getOracleData(address _address) public view returns (bytes32, bytes32, uint256, bool, bool, uint256, address);
    function getReservePercent() public view returns (uint256);

    /* Constant setters */
    function attachToken(address _tokenAddress) public;
    function setOracleTimeout(uint256 _period) public;
    function setOracleActual(uint256 _period) public;
    function setRatePeriod(uint256 _period) public;
    function setLock(bool lock) public;

    /* Tokens admin methods */
    function transferTokenOwner(address newOwner) public;
    function claimOwnership() public;
}