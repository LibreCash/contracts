pragma solidity ^0.4.10;

import "./oraclizeAPI_0.4.sol";
import "./zeppelin/ownership/Ownable.sol";

contract OracleBase is Ownable, usingOraclize {
    event NewOraclizeQuery(string description);
    event NewPriceTicker(string oracleName, uint256 price, uint256 timestamp);

    string public name;
    string public description;
    uint256 lastResult;
    string oracleType; // Human-readable oracle type e.g ETHUSD
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

    function OracleBase(string _name, string _datasource, string _arguments, string _type) public {
        owner = msg.sender;
        name = _name;
        oracleType = _type;
        config.datasource = _datasource;
        config.arguments = _arguments;
        updateCost = 2*oraclize_getPrice(_datasource);
    }

// не понял, зачем тут эти две функции (далее закомментил), они в дочерних контрактах описываются
// можно этот контракт сделать абстрактным и описать их заголовки только
// возможно, я не прав
// Дима
 /*   function update(uint delay, uint _BSU, address _address, uint256 _amount, uint _limit) payable {
        require(this.balance > updateCost);
        bytes32 queryId = oraclize_query(delay, config.datasource, config.arguments);
        validIds[queryId] = true;
        NewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
    }

    function __callback(bytes32 myid, string result, bytes proof) {
        require (msg.sender == oraclize_cbAddress());
        uint256 currentTime = now;
        uint ETHUSD = parseInt(result, 2); // in $ cents
        lastResult = ETHUSD;
        lastResultTimestamp = currentTime;
        delete validIds[myid];
        NewPriceTicker(name,ETHUSD,currentTime);
    }*/

    function getName() constant returns(string) public {
        return name;
    }

    function getType() constant returns(string) public {
        return oracleType;
    }
}