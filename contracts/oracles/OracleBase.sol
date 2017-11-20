pragma solidity ^0.4.10;

import "./oraclizeAPI_0.4.sol";
import "../zeppelin/ownership/Ownable.sol";
import "../library/Helpers.sol";
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
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once
    address public bankAddress;
    uint256 public rate;
    bytes32 public queryId;
    uint256 public minUpdateTime = 5 minutes;
    OracleConfig public oracleConfig; // заполняется конструктором потомка константами из него же

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
     * Clears queryId and rate.
     */
    function clearState() public onlyBank {
        queryId = 0x0;
        rate = 0;
        updateTime = 0;
    }

    /**
     * @dev Sets bank address.
     * @param _bankAddress Address of bank contract.
     */
    function setBank(address _bankAddress) public onlyOwner {
        bankAddress = _bankAddress;
    }

    /**
     * @dev Sends query to oraclize.
     */
    function updateRate() external onlyBank returns (bool) {
        // для тестов отдельно оракула закомментировать след. строку
        require (now > updateTime + minUpdateTime);
        if (oraclize_getPrice(oracleConfig.datasource) > this.balance) {
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

}