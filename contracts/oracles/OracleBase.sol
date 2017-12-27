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
contract OracleBase is Ownable, usingOraclize, OracleI {
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
    uint256 public callbackTime;
    uint256 public priceLimit = 1 ether;

    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once
    address public bankAddress;
    uint256 public rate;
    bool public waitQuery = false;
    OracleConfig public oracleConfig; // заполняется конструктором потомка константами из него же

    // public для тестов, но может и оставим
    uint256 public gasPrice = 20 * 10**9;
    uint256 public gasLimit = 100000;

    uint256 constant MIN_GAS_PRICE = 2 * 10**9; // чтобы мы не могли убить работу контракта полностью
    uint256 constant MAX_GAS_PRICE = 1000 * 10**9; // мало ли что будет с сетью, но больше 1000 ГВей за газ вряд ли будет (?)
    uint256 constant MIN_GAS_LIMIT = 95000; // по факту 87600+ стоит, чтобы мы не могли убить контракт
    uint256 constant MAX_GAS_LIMIT = 10000000; // ну и чтоб не заставляли людей платить слишком много, перестав сами обновлять данные

    modifier onlyBank() {
        require(msg.sender == bankAddress);
        _;
    }

    /**
     * @dev Constructor.
     */
    function OracleBase(address _bankAddress) public {
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        bankAddress = _bankAddress;
        BankSet(_bankAddress);
    }

    /**
     * @dev Sets oraclize price limit (maximum query cost).
     * @param _limit New limit.
     */
    function setPriceLimit(uint256 _limit) public onlyOwner {
        priceLimit = _limit;
    }

    /**
     * @dev Sets gas price.
     * @param _price New gas price.
     */
    function setGasPrice(uint256 _price) public onlyOwner {
        require((_price >= MIN_GAS_PRICE) && (_price <= MAX_GAS_PRICE));
        gasPrice = _price;
        oraclize_setCustomGasPrice(gasPrice);
    }

    /**
     * @dev Sets gas limit.
     * @param _limit New gas limit.
     */
    function setGasLimit(uint256 _limit) public onlyOwner {
        require((_limit >= MIN_GAS_LIMIT) && (_limit <= MAX_GAS_LIMIT));
        gasLimit = _limit;
    }

    /**
     * Clears queryId, updateTime and rate.
     */
    function clearState() public onlyBank {
        waitQuery = false;
        rate = 0;
        updateTime = 0;
        callbackTime = 0;
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
    function getPrice() public view returns (uint) {
        return oraclize_getPrice(oracleConfig.datasource, gasLimit);
    }

    /**
     * @dev Requests updating rate from oraclize.
     */
    function updateRate() external onlyBank returns (bool) {
        if (getPrice() > this.balance) {
            NewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
            return false;
        } else {
            bytes32 queryId = oraclize_query(oracleConfig.datasource, oracleConfig.arguments, gasLimit, priceLimit);
            if (queryId == bytes32(0)) {
                NewOraclizeQuery("Oraclize query was NOT sent, unexpectedly high query price");
                return false;
            }
            NewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
            validIds[queryId] = true;
            waitQuery = true;
            updateTime = now;
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
        require(msg.sender == oraclize_cbAddress());
        rate = Helpers.parseIntRound(result, 3); // save it in storage as 1/1000 of $
        NewPriceTicker(result);
        delete validIds[myid];
        callbackTime = now;
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