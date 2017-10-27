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
contract OracleBase is Ownable, usingOraclize {
    event NewOraclizeQuery(string description);
    event NewPriceTicker(bytes32 oracleName, uint256 price, uint256 timestamp);
    event NewPriceTicker(string price);
    event Log(string description);

    struct OracleConfig {
        string datasource;
        string arguments;
    }

    bytes32 public oracleName = "Base Oracle";
    bytes16 public oracleType = "Undefined";
    string public description; // либо избавиться, либо в байты переделать
    //uint256 public lastResult; // по сути это rate
    uint256 public lastResultTimestamp;
    uint256 public updateCost;
    //address public owner; // убрать со след. коммитом, по идее это не нужно
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
        //owner = msg.sender; // убрать со след. коммитом, по идее это не нужно
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    }

    /**
     * @dev Returns if oraclize callback is received. Is needed for automated tests only.
     */
    function hasReceivedRate() public view returns (bool) {
        return receivedRate;
    }

    // TODO: onlyOwner, onlyBank - подумать ещё раз, что когда нужно, и мб сделать общий модификатор onlyOwnerOrBank
    /**
     * @dev Sets oracle description.
     * @param _description Description.
     * TODO: нужно ли вообще оракулу описание?
     */
    function setDescription(string _description) onlyOwner public {
        description = _description;
    }

    /**
     * @dev Sets bank address.
     * @param _bankAddress Description.
     */
    function setBank(address _bankAddress) public {
        bankAddress = _bankAddress;
        bank = bankInterface(_bankAddress);
    }

    // for test
    /**
     * @dev Gets bank address.
     */
    function getBank() public view returns (address) {
        return bankAddress;
    }

    /**
     * @dev Sends query to oraclize.
     */
    function updateRate() payable public /*onlyBank*/ returns (bytes32) {
        // для тестов отдельно оракула закомментировать след. строку
        require (msg.sender == bankAddress);
        // для тестов отдельно оракула закомментировать след. строку
        require (now > lastResultTimestamp + MIN_UPDATE_TIME);
        receivedRate = false;
        if (oraclize_getPrice("URL") > this.balance) {
            NewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
            return 0;
            //bank.OraclizeStatus(address(this), oracleName, "Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            bytes32 queryId = oraclize_query(0, oracleConfig.datasource, oracleConfig.arguments);
            NewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
            //bank.OraclizeStatus(address(this), oracleName, "Oraclize query was sent, standing by for the answer...");
            validIds[queryId] = true;
            return queryId;
        }
    }

    /**
    * @dev Oraclize default callback with the proof set.
    */
   function __callback(bytes32 myid, string result, bytes proof) public {
        require(validIds[myid]);
        require(msg.sender == oraclize_cbAddress());
        receivedRate = true;
        NewPriceTicker(result);
        rate = parseInt(result, 2); // save it in storage as $ cents
        delete(validIds[myid]);
        lastResultTimestamp = now;
        bank.oraclesCallback(rate, now);
    }

    /**
     * @dev Updates oraclize costs.
     * Shall be run after datasource setting.
     */
    function updateCosts() internal {
        updateCost = 2 * oraclize_getPrice(oracleConfig.datasource);
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