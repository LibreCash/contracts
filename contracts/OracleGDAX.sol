pragma solidity ^0.4.11;

import "./zeppelin/ownership/Ownable.sol";
import "./OracleBase.sol";

contract OracleGDAX is OracleBase {
    bytes32 constant ORACLE_NAME = "GDAX Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://api.gdax.com/products/ETH-USD/ticker).ask";
    
    function OracleGDAX(address _bankContract) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
        bankContractAddress = _bankContract;
        updateCosts();
    }
     
    function donate() payable { }
}
