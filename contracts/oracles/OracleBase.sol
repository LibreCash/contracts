pragma solidity ^0.4.18;

import "./OraclizeAPI.sol";
import "../zeppelin/ownership/Ownable.sol";
import "../library/Helpers.sol";
import "../interfaces/I_Oracle.sol";


/**
 * @title Base contract for Oraclize oracles.
 *
 * @dev Base contract for oracles. Not abstract.
 */
contract OracleBase is Ownable, usingOraclize, OracleI {
    event NewOraclizeQuery();
    event OraclizeError(string desciption);
    event PriceTicker(string price, bytes32 queryId, bytes proof);
    event BankSet(address bankAddress);

    struct OracleConfig {
        string datasource;
        string arguments;
    }

    bytes32 public oracleName = "Base Oracle";
    bytes16 public oracleType = "Undefined";
    uint256 public updateTime;
    uint256 public callbackTime;
    uint256 public priceLimit = 1 ether;

    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once
    address public bankAddress;
    uint256 public rate;
    bool public waitQuery = false;
    OracleConfig public oracleConfig;

    
    uint256 public gasPrice = 20 * 10**9;
    uint256 public gasLimit = 100000;

    uint256 constant MIN_GAS_PRICE = 1 * 10**9; // Min gas price limit
    uint256 constant MAX_GAS_PRICE = 100 * 10**9; // Max gas limit pric
    uint256 constant MIN_GAS_LIMIT = 95000; 
    uint256 constant MAX_GAS_LIMIT = 1000000;
    uint256 constant MIN_REQUEST_PRICE = 0.001118 ether;

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
     * @dev Sets gas price.
     * @param priceInWei New gas price.
     */
    function setGasPrice(uint256 priceInWei) public onlyOwner {
        require((priceInWei >= MIN_GAS_PRICE) && (priceInWei <= MAX_GAS_PRICE));
        gasPrice = priceInWei;
        oraclize_setCustomGasPrice(gasPrice);
    }

    /**
     * @dev Sets gas limit.
     * @param _gasLimit New gas limit.
     */
    function setGasLimit(uint256 _gasLimit) public onlyOwner {
        require((_gasLimit >= MIN_GAS_LIMIT) && (_gasLimit <= MAX_GAS_LIMIT));
        gasLimit = _gasLimit;
    }

    /**
     * @dev Sets bank address.
     * @param bank Address of the bank contract.
     */
    function setBank(address bank) public onlyOwner {
        bankAddress = bank;
        BankSet(bankAddress);
    }

    /**
     * @dev oraclize getPrice.
     */
    function getPrice() public view returns (uint) {
        return oraclize_getPrice(oracleConfig.datasource, gasLimit);
    }

    /**
     * @dev Requests updating rate from oraclize.
     */
    function updateRate() external onlyBank returns (bool) {
        if (getPrice() > this.balance) {
            OraclizeError("Not enough ether");
            return false;
        }
        bytes32 queryId = oraclize_query(oracleConfig.datasource, oracleConfig.arguments, gasLimit, priceLimit);
        
        if (queryId == bytes32(0)) {
            OraclizeError("Unexpectedly high query price");
            return false;
        }

        NewOraclizeQuery();
        validIds[queryId] = true;
        waitQuery = true;
        updateTime = now;
        return true;
    }

    /**
    * @dev Oraclize default callback with the proof set.
    * @param myid The callback ID.
    * @param result The callback data.
    * @param proof The oraclize proof bytes.
    */
    function __callback(bytes32 myid, string result, bytes proof) public {
        require(validIds[myid] && msg.sender == oraclize_cbAddress());

        rate = Helpers.parseIntRound(result, 3); // save it in storage as 1/1000 of $
        delete validIds[myid];
        callbackTime = now;
        waitQuery = false;
        PriceTicker(result, myid, proof);
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