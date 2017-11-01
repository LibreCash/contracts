pragma solidity ^0.4.10;

import "./oraclizeAPI_0.4.sol";
import "./zeppelin/ownership/Ownable.sol";

interface bankInterface {
    // TODO: research events in interfaces (TypeError: Member "OraclizeStatus" not found or not visible after argument-dependent lookup in contract bankInterface)
    //event OraclizeStatus(address indexed _address, bytes32 oraclesName, string description);
    function oraclesCallback(uint256 value, uint256 timestamp) public;
}

/**
 * @title Base contract for oracles.
 *
 * @dev Base contract for oracles. Not abstract.
 */
contract LocalOracleBase is Ownable {

    struct OracleConfig {
        string datasource;
        string arguments;
    }

    bytes32 public oracleName = "Local Oracle";
    bytes16 public oracleType = "DUMMY";
    uint256 public lastResultTimestamp;
    uint256 public string rateData = "30000";
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once
    address public bankAddress;
    uint public rate;
    bankInterface bank;
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
    function OracleBase() public {
        oracleConfig = OracleConfig({datasource: "", arguments: "";});
        bankAddress = _bankAddress;
        updateCosts();
    }

    /**
     * @dev Sets bank address.
     * @param _bankAddress Description.
     */
    function setBank(address _bankAddress) public {
        bankAddress = _bankAddress;
        bank = bankInterface(_bankAddress);
    }

    /**
     * @dev Sends query to oraclize.
     */
    function updateRate() payable public /*onlyBank*/ returns (bytes32) {
        // для тестов отдельно оракула закомментировать след. строку
        require (msg.sender == bankAddress);
        // для тестов отдельно оракула закомментировать след. строку
        require (now > lastResultTimestamp + MIN_UPDATE_TIME);
        // это локальный вариант оракула, тут не будет ораклайза, а просто:
        __callback("dummyId", rateData, "proof");
    }

    /**
    * @dev Oraclize default callback with the proof set.
    */
    function __callback(bytes32 myid, string result, bytes proof) public {
        rate = parseInt(result, 2); // save it in storage as $ cents
        lastResultTimestamp = now;
        bank.oraclesCallback(rate, now);
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