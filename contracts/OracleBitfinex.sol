pragma solidity ^0.4.11;

import "./zeppelin/ownership/Ownable.sol";
import "./OracleBase.sol";

interface bankInterface {
    function oraclesCallback (uint256 value, uint256 timestamp) ;
}

contract OracleKraken is  OracleBase {
//    string public constant name = "Bitfinex Oraclize Async";
//    string public constant oracleType = "ETHUSD";
    address public bankContractAddress;
//    address public owner;
    uint public rate;
    bankInterface bank;
    bytes32 oracleName = "Bitfinex Oraclize Async";
    bytes16 oracleType = "ETHUSD";
    string datasource = "URL";
    // https://bitfinex.readme.io/v1/reference#rest-public-ticker
    string arguments = "json(https://api.bitfinex.com/v1/pubticker/ethusd).mid";
    
    event newOraclizeQuery(string description);
    event newPriceTicker(string price); 
    
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once

// закомментил что есть в oracleBase.sol
//    event NewOraclizeQuery(string description);
//    event NewPriceTicker(string price);

/*    struct OracleConfig {
        string datesource;
        string arguments;
    }*/

//    OracleConfig public config;
   
    // такой тип наследования описан: https://github.com/ethereum/wiki/wiki/%5BRussian%5D-%D0%A0%D1%83%D0%BA%D0%BE%D0%B2%D0%BE%D0%B4%D1%81%D1%82%D0%B2%D0%BE-%D0%BF%D0%BE-Solidity#arguments-for-base-constructors
    function OracleKraken() OracleBase(oracleName, datasource, arguments, oracleType) public { //OracleBase(oracleName, datasource, arguments, oracleType)
        owner = msg.sender;

        //bankContractAddress = _bankContract;
       
        
        //config.datasource = datasource;
        // mid - среднее значение между bid и ask у битфинекса, считаю целесообразным
        // https://bitfinex.readme.io/v1/reference#rest-public-ticker
        //config.arguments = arguments;
        // FIXME: enable oraclize_setProof is production
        // разобраться с setProof - что с ним не так? - Дима
        //oraclize_setProof(proofType_TLSNotary);
        update();
    }
    
    function setBank (address _bankContract) public {
        bankContractAddress = _bankContract;
        bank = bankInterface(_bankContract);//0x14D00996c764aAce61b4DFB209Cc85de3555b44b Rinkeby bank address
    }

    // модификатор временно убрал, пока он не реализован
    function update() payable {
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            bytes32 queryId = oraclize_query(0, config.datasource, config.arguments);
            validIds[queryId] = true;
        }
    }  
    
    function __callback(bytes32 myid, string result, bytes proof) {
        require(validIds[myid]);
        require(msg.sender == oraclize_cbAddress());
        newPriceTicker(result);
        rate = parseInt(result, 2); // save it in storage as $ cents
        // do something with rate
        delete(validIds[myid]);
        bank.oraclesCallback (rate, now);
    }    
    function donate() payable  {}
    // Sending ether directly to the contract invokes buy() and assigns tokens to the sender 


}