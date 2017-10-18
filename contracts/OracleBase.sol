pragma solidity ^0.4.10;

import "./oraclizeAPI_0.4.sol";
import "./zeppelin/ownership/Ownable.sol";

interface bankInterface {
    function oraclesCallback(address _address, uint256 value, uint256 timestamp);
}

contract OracleBase is Ownable, usingOraclize {
    event NewOraclizeQuery(string description);
    // надеюсь, нет ограничений на использование bytes32 в событии. Надо посмотреть, как web3.js это воспримет
    event NewPriceTicker(bytes32 oracleName, uint256 price, uint256 timestamp);
    event newOraclizeQuery(string description);
    event newPriceTicker(string price); 

    bytes32 public oracleName = "Base Oracle";
    bytes16 public oracleType = "Undefined"; // Human-readable oracle type e.g ETHUSD
    string public description;
    uint256 lastResult;
    uint256 lastResultTimestamp;
    uint256 public updateCost;
    address public owner;
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once
    address public bankContractAddress;
    uint public rate;
    bankInterface bank;
    // пока не знаю, надо ли. добавил как флаг для тестов
    bool public receivedRate = false;

    struct OracleConfig {
        string datasource;
        string arguments;
    }

    OracleConfig public oracleConfig;

    function hasReceivedRate() public returns (bool) {
        return receivedRate;
    }


    function OracleBase() public {
        owner = msg.sender;
        oraclize_setProof(proofType_TLSNotary);
    }

    /**
     * @dev Sets oracle description.
     * @param _description Description.
     */
    function setDescription(string _description) onlyOwner public {
        description = _description;
    }

    function setBank(address _bankContract) public {
        bankContractAddress = _bankContract;
        //bank = bankInterface(_bankContract);//0x14D00996c764aAce61b4DFB209Cc85de3555b44b Rinkeby bank address
    }

    function update() payable public {
        require (msg.sender == bankContractAddress);
        receivedRate = false;
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer...");
            bytes32 queryId = oraclize_query(0, oracleConfig.datasource, oracleConfig.arguments);
            validIds[queryId] = true;
        }
    }  
    
   function __callback(bytes32 myid, string result, bytes proof) public {
        require(validIds[myid]);
        require(msg.sender == oraclize_cbAddress());
        receivedRate = true;
        newPriceTicker(result);
        rate = parseInt(result, 2); // save it in storage as $ cents
        // do something with rate
        delete(validIds[myid]);
        bank.oraclesCallback(bankContractAddress, rate, now);
    }



    /**
     * @dev Updates oraclize costs.
     * Shall run after datasource setting.
     */
    function updateCosts() internal {
        updateCost = 2*oraclize_getPrice(oracleConfig.datasource);
    }


 /*   function update() payable {
        require(this.balance > updateCost);
        bytes32 queryId = oraclize_query(0, config.datasource, config.arguments);
        validIds[queryId] = true;
        NewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
    }

    function __callback(bytes32 myid, string result, bytes proof) {
        require (msg.sender == oraclize_cbAddress());
        uint256 currentTime = now;
        uint ETHUSD = parseInt(result, 2); // in $ cents
        lastResult = ETHUSD;
        lastResultTimestamp = currentTime;
        delete(validIds[myid]);
        NewPriceTicker(oracleName, ETHUSD, currentTime);
    }*/

    function getName() constant public returns(bytes32) {
        return oracleName;
    }

    function getType() constant public returns(bytes16) {
        return oracleType;
    }
}