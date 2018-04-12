pragma solidity ^0.4.18;

import "../zeppelin/ownership/Ownable.sol";
import "../interfaces/I_Oracle.sol";

/**
 * @title Base contract for mocked oracles for testing in private nodes.
 *
 * @dev Base contract for oracles. Not abstract.
 */
contract BountyOracle is Ownable {

    bytes32 public oracleName = "Bounty Base Oracle";
    bytes16 public oracleType = "Bounty Undefined";
    mapping (address => uint256) public rates;
    uint256 public mockRate;
    event PriceTicker(uint price);

    mapping (address => uint256) public updateTimes;
    mapping (address => uint256) public callbackTimes;
    mapping (address => bool) public waitQuerys;
    uint256 constant MOCK_REQUEST_PRICE = 10000000000;
    mapping (address => uint256) public prices;
    
    function waitQuery() public returns (bool) {
        return waitQuerys[msg.sender];
    }

    function price() public returns (uint256) {
        return prices[msg.sender];
    }
    
    function rate() public returns (uint256) {
        return rates[msg.sender];
    }
    
    function updateTime() public returns (uint256) {
        return updateTimes[msg.sender];
    }
    
    function callbackTime() public returns (uint256) {
        return callbackTimes[msg.sender];
    }
    
    modifier onlyBank() {
        // allow everybody
        _;
    }

    /**
     * @dev Constructor.
     */
    function OracleBase(uint256 defaultMockRate) public {
        rates[msg.sender] = defaultMockRate;
    }

    /**
     * @dev oraclize getPrice.
     */
    function getPrice() public view returns (uint) {
        return prices[msg.sender];
    }

    /**
     * @dev Sends query to oraclize.
     */
    function updateRate() external onlyBank returns (bool) {
        updateTimes[msg.sender] = now;
        callbackTimes[msg.sender] = now;
        rates[msg.sender] = mockRate;

        if (prices[msg.sender] == 0) 
            prices[msg.sender] = MOCK_REQUEST_PRICE;

        PriceTicker(rates[msg.sender]);
        return true;
    }

    function setWaitQuery(bool waiting) external {
        waitQuerys[msg.sender] = waiting;
    }
    
    function setRate(uint newRate) external {
        rates[msg.sender] = newRate;
    }

    /**
    * @dev Method used for oracle funding   
    */    
    function () public payable { }
}