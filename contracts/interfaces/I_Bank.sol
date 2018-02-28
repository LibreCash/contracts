pragma solidity ^0.4.17;

interface BankI {
    /* Order creation && cancelation */
    function buyTokens(address _recipient, uint256 _rateLimit) payable public;
    function sellTokens(address _recipient, uint256 _tokensCount, uint256 _rateLimit) public;
    function cancelBuyOwner(uint256 _orderID) public;
    function cancelSellOwner(uint256 _orderID) public;

    /* Order queue processing */
    function processBuyQueue(uint256 _limit) public;
    function processSellQueue(uint256 _limit) public;

    /* Rate calc & init  params */
    function calcRates() public;
    function requestRates() payable public;
    
    /* Data getters */
    function claimBalance() public;
    function getBalance() public view returns (uint256);
    function getBalance(address _address) public view returns (uint256);
    function getBuyOrder(uint256 _orderID) public view returns (address, address, uint256, uint256, uint256);
    function getSellOrder(uint256 _orderID) public view returns (address, address, uint256, uint256, uint256);
    function getSellOrdersCount() public view returns(uint256);
    function getBuyOrdersCount() public view returns(uint256);
    function readyOracles() public view returns (uint256);
    function getOracleData(address _address) public view returns (bytes32, bytes32, uint256, bool, bool, uint256, address);
    function getReservePercent() public view returns (uint256);
    function totalTokens() public view returns (uint256);

    /* Constant setters */
    function attachToken(address _tokenAddress) public;

    /* Tokens admin methods */
    function transferTokenOwner(address newOwner) public;
    function claimOwnership() public;
}