pragma solidity ^0.4.11;

import "./zeppelin/ownership/Ownable.sol";

interface bankInterface {
    function __callback(uint256 value, uint256 timestamp) ;
}

contract oracle is Ownable, usingOraclize {
    string public constant name = "Bitinex Oraclize Async";
    string public constant oracleType = "ETHUSD";
    address public bankContractAddress;
    address public owner;
    uint public ETHUSD;
    bankInterface bank;
    event newOraclizeQuery(string description);
    event newPriceTicker(string price);

    function oracle (address _bankContract) {
        owner = msg.sender;
        bankContractAddress = _bankContract;
        bank = bankInterface(bankContractAddress);
    }

    function update() payable onlyBank {
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            oraclize_query(delay, datasource, argument);
          
        }
    }  
    
    function __callback(bytes32 myid, string result, bytes proof) {if (msg.sender != oraclize_cbAddress()) throw;
        newPriceTicker(result);
        ETHUSD = parseInt(result, 2); // save it in storage as $ cents
        // do something with ETHUSD
        bank.__callback(ETHUSD, now);
    }    
        
}