pragma solidity ^0.4.11;

import "./oraclizeAPI_0.4.sol";
import "./zeppelin/ownership/Ownable.sol";

interface bankInterface {
    function oraclesCallback(address _address, uint256 value, uint256 timestamp);
}

contract OracleBitfinex2 is Ownable, usingOraclize {
    event newOraclizeQuery(string description);
    // надеюсь, нет ограничений на использование bytes32 в событии. Надо посмотреть, как web3.js это воспримет
 //   event newPriceTicker(string oracleName, uint256 price, uint256 timestamp);
    event newPriceTicker(string price);

    string public oracleName = "Bitfinex Oraclize Async";
    string public oracleType = "ETHUSD";
    uint256 lastResult;
    uint256 lastResultTimestamp;
    uint256 public updateCost;
    address public owner;
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once

    address public bankContractAddress;

    uint public rate;
    bankInterface bank;

    struct OracleConfig {
        string datasource;
        string arguments;
    }

    OracleConfig public oracleConfig;

    function OracleBitfinex2() public {
        owner = msg.sender;
        oracleConfig.datasource = "URL";
        oracleConfig.arguments = "json(https://api.bitfinex.com/v1/pubticker/ethusd).mid";
        updateCost = 2*oraclize_getPrice("URL");
        oraclize_setProof(proofType_TLSNotary);
        update();
    }

    function setBank (address _bankContract) public {
        bankContractAddress = _bankContract;
        //bank = bankInterface(_bankContract);//0x14D00996c764aAce61b4DFB209Cc85de3555b44b Rinkeby bank address
    }

    // модификатор временно убрал, пока он не реализован
     function update() payable public {
        //require (msg.sender == bankContractAddress);
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
        newPriceTicker(result);
        rate = parseInt(result, 2); // save it in storage as $ cents
        // do something with rate
        delete(validIds[myid]);
        bank.oraclesCallback(bankContractAddress, rate, now);
    }
    
    function donate() payable { }
    // Sending ether directly to the contract invokes buy() and assigns tokens to the sender 


}