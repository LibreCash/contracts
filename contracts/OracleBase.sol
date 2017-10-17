pragma solidity ^0.4.10;

import "./oraclizeAPI_0.4.sol";
import "./zeppelin/ownership/Ownable.sol";

contract OracleBase is Ownable, usingOraclize {
    event NewOraclizeQuery(string description);
    // надеюсь, нет ограничений на использование bytes32 в событии. Надо посмотреть, как web3.js это воспримет
    event NewPriceTicker(bytes32 oracleName, uint256 price, uint256 timestamp);

    bytes32 public oracleName;
    bytes16 public oracleType; // Human-readable oracle type e.g ETHUSD
    string public description;
    uint256 lastResult;
    uint256 lastResultTimestamp;
    uint256 public updateCost;
    address public owner;
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once

    struct OracleConfig {
        string datasource;
        string arguments;
    }

    OracleConfig public config;

    function setDescription(string _description) onlyOwner public {
        description = _description;
    }

    function OracleBase(bytes32 _name, string _datasource, string _arguments, bytes16 _type) public {
        owner = msg.sender;
        oracleName = _name;
        oracleType = _type;
        config.datasource = _datasource;
        config.arguments = _arguments;
        updateCost = 2*oraclize_getPrice(_datasource);
    }


    function update() payable {
        require(this.balance > updateCost);
        bytes32 queryId = oraclize_query(0, config.datasource, config.arguments);
        validIds[queryId] = true;
        NewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
    }

    function __callback(bytes32 myid, string result/*, bytes proof*/) {
        require (msg.sender == oraclize_cbAddress());
        uint256 currentTime = now;
        // where is parseInt? shall we declare? http://remebit.com/converting-strings-to-integers-in-solidity/
        uint ETHUSD = parseInt(result, 2); // in $ cents
        lastResult = ETHUSD;
        lastResultTimestamp = currentTime;
        delete(validIds[myid]);
        NewPriceTicker(oracleName, ETHUSD, currentTime);
    }

    function getName() constant public returns(bytes32) {
        return oracleName;
    }

    function getType() constant public returns(bytes16) {
        return oracleType;
    }
}