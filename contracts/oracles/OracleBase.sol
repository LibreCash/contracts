pragma solidity ^0.4.10;

import "./oraclizeAPI_0.4.sol";
import "../zeppelin/ownership/Ownable.sol";
import "../library/Helpers.sol";
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
    uint256 public updateTime;
    uint256 public updateCost;
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once
    address public bankAddress;
    uint256 internal rate;
    bytes32 internal queryId;
 //   BankI bank;
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
     * Returns rate.
     */
    function getRate() public returns (uint256) {
        return rate;
    }

    /**
     * Returns queryId.
     */
    function getQueryId() public returns (bytes32) {
        return queryId;
    }

    /**
     * Clears queryId and rate.
     */
    function clearState() public onlyBank {
        queryId = 0x0;
        rate = 0;
    }

    function getUpdateTime() public returns (uint256) {
        return updateTime;
    }

    /**
     * @dev Sets bank address.
     * @param _bankAddress Description.
     */
    function setBank(address _bankAddress) public onlyOwner {
        bankAddress = _bankAddress;
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
    function updateRate() external onlyBank returns (bool) {
        // для тестов отдельно оракула закомментировать след. строку
        require (now > updateTime + MIN_UPDATE_TIME);
        if (oraclize_getPrice("URL") > this.balance) {
            NewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
            return false;
        } else {
            queryId = oraclize_query(0, oracleConfig.datasource, oracleConfig.arguments);
            NewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
            validIds[queryId] = true;
            return true;
        }
    }

    /**
    * @dev Oraclize default callback with the proof set.
    */
   function __callback(bytes32 myid, string result, bytes proof) public {
        require(validIds[myid]);
        require(msg.sender == oraclize_cbAddress());
        NewPriceTicker(result);
        rate = Helpers.parseIntRound(result, 2); // save it in storage as $ cents
        NewPriceTicker(result);
        delete(validIds[myid]);
        updateTime = now;
        queryId = 0x0;
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