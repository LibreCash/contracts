pragma solidity ^0.4.10;

import "./oraclizeAPI_0.4.sol";
import "../zeppelin/ownership/Ownable.sol";
import "../interfaces/I_Bank.sol";
import "../interfaces/I_Oracle.sol";


/**
 * @title Base contract for oracles.
 *
 * @dev Base contract for oracles. Not abstract.
 */
contract OracleBase is Ownable, usingOraclize, OracleI {
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
    uint256 public lastResultTimestamp;
    uint256 public updateCost;
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once
    address public bankAddress;
    uint public rate;
    BankI bank;
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
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    }

    /**
     * @dev Sets bank address.
     * @param _bankAddress Description.
     */
    function setBank(address _bankAddress) public onlyOwner {
        bankAddress = _bankAddress;
        bank = BankI(_bankAddress);
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
    function updateRate() external onlyBank returns (bytes32) {
        // для тестов отдельно оракула закомментировать след. строку
        require (now > lastResultTimestamp + MIN_UPDATE_TIME);
        if (oraclize_getPrice("URL") > this.balance) {
            NewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
            return 0;
        } else {
            bytes32 queryId = oraclize_query(0, oracleConfig.datasource, oracleConfig.arguments);
            NewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
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
        NewPriceTicker(result);
        rate = parseInt(result, 2); // save it in storage as $ cents
        delete(validIds[myid]);
        lastResultTimestamp = now;
        bank.oraclesCallback(rate, now);
    }

    /**
    * @dev Oraclize default callback without the proof set.
    */
   function __callback(bytes32 myid, string result) public {
       bytes memory proof = new bytes(1);
       __callback(myid, result, proof);
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
     * @dev Shall receive crypto for oraclize queries.
     */
    function () payable external { }
}