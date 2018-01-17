pragma solidity ^0.4.11;

interface BankI {
    /* Order creation && cancelation */
    function createBuyOrder(address _address, uint256 _rateLimit) public;
    function createSellOrder(address _address, uint256 _tokensCount, uint256 _rateLimit) public;
    function cancelBuyOrderOwner(uint256 _orderID) public;
    function cancelSellOrderOwner(uint256 _orderID) public;

    /* Order queue processing */
    function processBuyQueue(uint256 _limit) public;
    function processSellQueue(uint256 _limit) public;

    /* Rate calc & init  params */
    function calcRates() public;
    function requestUpdateRates() public;
    
    /* Data getters */
    function getEther() public;
    function getBalanceEther() public view returns (uint256);
    function getBalanceEther(address _address) public view returns (uint256);
    function getBuyOrder(uint256 _orderID) public view returns (address, address, uint256, uint256, uint256);
    function getSellOrder(uint256 _orderID) public view returns (address, address, uint256, uint256, uint256);
    function getSellOrdersCount() public view returns(uint256);
    function getBuyOrdersCount() public view returns(uint256);
    function numReadyOracles() public view returns (uint256);
    function getOracleData(address _address) public view returns (bytes32, bytes32, uint256, bool, bool, uint256, address);
    function getReservePercent() public view returns (uint256);
    function totalTokenCount() public view returns (uint256);

    /* Oracles methods */
    function addOracle(address _address) public;
    function disableOracle(address _address) public;
    function enableOracle(address _address) public;
    function deleteOracle(address _address) public;
    
    /* Constant setters */
    function attachToken(address _tokenAddress) public;
    function setRelevancePeriod(uint256 _period) public;
    function setQueuePeriod(uint256 _period) public;
    function setFees(uint256 _buyFee, uint256 _sellFee) public;
    function schedulerUpdateRate(uint256 fund) public;
    function setScheduler(address _scheduler) public;
    function setBalanceCap(uint256 capInWei) public;
    function setWithdrawWallet(address withdrawTo) public;
    function setAutoWithdraw(bool _autoWithdraw) public;
    
    /* Funding management */
    function refillBalance() public;

    /* Tokens admin methods */
    function transferTokenOwner(address newOwner) public;
}