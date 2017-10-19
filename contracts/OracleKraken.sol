pragma solidity ^0.4.11;

import "./zeppelin/ownership/Ownable.sol";
import "./OracleBase.sol";

contract OracleKraken is OracleBase {
    bytes32 constant ORACLE_NAME = "Kraken Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0";
    
    function OracleKraken(address _bankContract) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
        bankContractAddress = _bankContract;
        updateCosts();
    }
     
    function donate() payable { }
}
