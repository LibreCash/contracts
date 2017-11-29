pragma solidity ^0.4.10;

import "./OraclizeAPI.sol";
import "../zeppelin/ownership/Ownable.sol";
import "../library/Helpers.sol";
import "../interfaces/I_Oracle.sol";



/**
 * @title Base contract for oracles.
 *
 * @dev Base contract for oracles. Not abstract.
 */
contract OracleBase is Ownable, OracleI {
    event NewOraclizeQuery(string description);
    event NewPriceTicker(bytes32 oracleName, uint256 price, uint256 timestamp);
    event NewPriceTicker(string price);
    event Log(string description);
    event BankSet(address bankAddress);

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
    bytes32 queryId;
    bool public waitQuery = false;
    OracleConfig public oracleConfig; // заполняется конструктором потомка константами из него же

    OraclizeAddrResolverI OAR;
    OraclizeI oraclize;
    string oraclize_network_name;


    modifier onlyBank() {
        require(msg.sender == bankAddress);
        _;
    }

    /**
     * @dev Constructor.
     */
    function OracleBase(address _bankAddress) {
        OraclizeAPI.oraclize_setProof(OraclizeAPI.proofType_TLSNotary() | OraclizeAPI.proofStorage_IPFS());
        bankAddress = _bankAddress;
        BankSet(_bankAddress);
    }

    /**
     * Clears queryId, updateTime and rate.
     */
    function clearState() public onlyBank {
        waitQuery = false;
        rate = 0;
        updateTime = 0;
    }

    /**
     * @dev Sets bank address.
     * @param _bankAddress Address of the bank contract.
     */
    function setBank(address _bankAddress) public onlyOwner {
        bankAddress = _bankAddress;
        BankSet(_bankAddress);
    }

    /**
     * @dev oraclize getPrice.
     */
    function getPrice() view public returns (uint) {
        return OraclizeAPI.oraclize_getPrice(oracleConfig.datasource);
    }

    /**
     * @dev Requests updating rate from oraclize.
     */
    function updateRate() external onlyBank returns (bool) {
        if (getPrice() > this.balance) {
            NewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
            return false;
        } else {
            queryId = OraclizeAPI.oraclize_query(0, oracleConfig.datasource, oracleConfig.arguments);
            NewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
            validIds[queryId] = true;
            waitQuery = true;
            return true;
        }
    }

    /**
    * @dev Oraclize default callback with the proof set.
    * @param myid The callback ID.
    * @param result The callback data.
    * @param proof The oraclize proof bytes.
    */
    function __callback(bytes32 myid, string result, bytes proof) public {
        require(validIds[myid]);
        require(msg.sender == OraclizeAPI.oraclize_cbAddress());
        rate = Helpers.parseIntRound(result, 3); // save it in storage as 1/1000 of $
        NewPriceTicker(result);
        delete(validIds[myid]);
        updateTime = now;
        waitQuery = false;
    }

    /**
    * @dev Oraclize default callback without the proof set.
    * @param myid The callback ID.
    * @param result The callback data.
    */
    function __callback(bytes32 myid, string result) public {
       bytes memory proof = new bytes(1);
       __callback(myid, result, proof);
    }

    /**
    * @dev Method used for oracle funding   
    */    
    function () public payable {}

}