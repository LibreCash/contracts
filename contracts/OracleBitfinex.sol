pragma solidity ^0.4.11;

import "./zeppelin/ownership/Ownable.sol";
import "./OracleBase.sol";

interface bankInterface {
    function oraclesCallback (uint256 value, uint256 timestamp) ;
}

contract OracleKraken is Ownable, OracleBase {
    string public constant name = "Bitfinex Oraclize Async";
    string public constant oracleType = "ETHUSD";
    address public bankContractAddress;
//    address public owner;
    uint public ETHUSD;
    bankInterface bank;
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once

// закомментил что есть в oracleBase.sol
//    event NewOraclizeQuery(string description);
//    event NewPriceTicker(string price);

/*    struct OracleConfig {
        string datesource;
        string arguments;
    }*/

//    OracleConfig public config;
   

    function OracleKraken (address _bankContract) public {
        owner = msg.sender;
        bankContractAddress = _bankContract;
        bank = bankInterface(bankContractAddress);
        config.datasource = "URL";
        // mid - среднее значение между bid и ask у битфинекса, считаю целесообразным
        config.arguments = "json(https://api.bitfinex.com/v1/pubticker/ethusd).mid";
        // FIXME: enable oraclize_setProof is production
        // разобраться с setProof - что с ним не так? - Дима
        oraclize_setProof(proofType_TLSNotary);
    }

    // модификатор временно убрал, пока он не реализован
    function update() payable /*onlyBank*/ public {
        if (oraclize_getPrice("URL") > this.balance) {
            NewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            NewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            bytes32 queryId = oraclize_query(0, config.datasource, config.arguments);
            validIds[queryId] = true;
        }
    }  
    
    function __callback(bytes32 myid, string result, bytes proof) {
        require(validIds[myid]);
        require(msg.sender == oraclize_cbAddress());
        NewPriceTicker(result);
        ETHUSD = parseInt(result, 2); // save it in storage as $ cents
        // do something with ETHUSD
        delete validIds[myid];
        bank.oraclesCallback (ETHUSD, now);
    }    
        
}