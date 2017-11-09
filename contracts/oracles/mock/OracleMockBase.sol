pragma solidity ^0.4.10;

import "../../zeppelin/ownership/Ownable.sol";
import "../../interfaces/I_Bank.sol";
import "../../interfaces/I_Oracle.sol";

/**
 * @title Base contract for mocked oracles for testing in private nodes.
 *
 * @dev Base contract for oracles. Not abstract.
 */
contract OracleMockBase is Ownable {

    bytes32 public oracleName = "Mocked Base Oracle";
    bytes16 public oracleType = "Mocked Undefined";
    uint rate = 100;
    event NewOraclizeQuery(string description);
    event NewPriceTicker(bytes32 oracleName, uint256 price, uint256 timestamp);
    event NewPriceTicker(string price);
    event Log(string description);

    struct OracleConfig {
        string datasource;
        string arguments;
    }

    string public description; // либо избавиться, либо в байты переделать
    uint256 public lastResultTimestamp;
    uint256 public updateCost;
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once
    address public bankAddress;
    BankI bank;
    bool public receivedRate = false; // флаг, нужен для автоматизированных тестов
    uint256 MIN_UPDATE_TIME = 5 minutes;
    OracleConfig internal oracleConfig; // заполняется конструктором потомка константами из него же

    modifier onlyBank() {
        require(msg.sender == bankAddress);
        _;
    }

    /**
     * @dev Constructor.
     */
    function OracleBase(uint256 defaultMockRate) public {
        rate = defaultMockRate;
    }

    /**
     * @dev Sets bank address.
     * @param _bankAddress Description.
     */
    function setBank(address _bankAddress) public {
        bankAddress = _bankAddress;
        bank = BankI(_bankAddress);
    }

    /**
     * @dev Gets bank address.
     */
    function getBank() public view returns (address) {
        return bankAddress;
    }

    /**
     * @dev Sends query to oraclize.
     */
    function updateRate() external returns (bytes32) {
        // для тестов отдельно оракула закомментировать след. строку
        require (msg.sender == bankAddress);
        // для тестов отдельно оракула закомментировать след. строку
        require (now > lastResultTimestamp + MIN_UPDATE_TIME);
        lastResultTimestamp = now;
        bank.oraclesCallback(rate, now);
    }

    
    function setRate(uint newRate) external {
        rate = newRate;
    }

    /**
    * @dev default callback with the proof set.
    */
   function __callback(bytes32, string, bytes) public {
        // Do nothing
    }

    /**
    * @dev Oraclize default callback without the proof set.
    */
   function __callback(bytes32, string) public {
       // Do nothing
    }


    /**
     * @dev Returns the oracle name.
     */
    function getName() constant public returns (bytes32) {
        return oracleName;
    }

    /**
     * @dev Returns the oracle type.
     */
    function getType() constant public returns (bytes16) {
        return oracleType;
    }

    /**
     * @dev Shall receive ETH for oraclize queries.
     */
    function () payable external { }
}