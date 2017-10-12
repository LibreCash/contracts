pragma solidity ^0.4.11;

import "./zeppelin/ownership/Ownable.sol";
import "./oracleBase.sol";

interface bankInterface {
    function oraclesCallback (uint256 value, uint256 timestamp) ;
}

contract oracle is Ownable, oracleBase {
    string public constant name = "Bitfinex Oraclize Async";
    string public constant oracleType = "ETHUSD";
    address public bankContractAddress;
    address public owner;
    uint public ETHUSD;
    bankInterface bank;
    event newOraclizeQuery(string description);
    event newPriceTicker(string price);

    struct oracleConfig {
        string datesource;
        string arguments;
    }

    oracleConfig public config;
   

    function oracle (address _bankContract) {
        owner = msg.sender;
        bankContractAddress = _bankContract;
        bank = bankInterface(bankContractAddress);
        config.datasource = "URL";
        config.arguments = "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0";
    }

    function update() payable onlyBank {
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            oraclize_query(0, config.datasource, config.arguments); 
        }
    }  
    
    function __callback(bytes32 myid, string result, bytes proof) {if (msg.sender != oraclize_cbAddress()) throw;
        newPriceTicker(result);
        ETHUSD = parseInt(result, 2); // save it in storage as $ cents
        // do something with ETHUSD
        bank.oraclesCallback (ETHUSD, now);
    }    
        
}