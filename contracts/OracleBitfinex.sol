pragma solidity ^0.4.11;

import "./zeppelin/ownership/Ownable.sol";
import "./OracleBase.sol";

contract OracleBitfinex is OracleBase {
    bytes32 constant ORACLE_NAME = "Bitfinex Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    // https://bitfinex.readme.io/v1/reference#rest-public-ticker
    string constant ORACLE_ARGUMENTS = "json(https://api.bitfinex.com/v1/pubticker/ethusd).mid";
    
    function OracleBitfinex() public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
        updateCosts();
        //update();
    }
    

    // for tests
    function getRate() public returns(uint256) {
        return rate;
    }

    
    function donate() payable { }
    // Sending ether directly to the contract invokes buy() and assigns tokens to the sender 


}