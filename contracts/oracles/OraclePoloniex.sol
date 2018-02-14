pragma solidity ^0.4.17;

import "./OracleBase.sol";

contract OraclePoloniex is OracleBase {
    bytes32 constant ORACLE_NAME = "Poloniex Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    // https://poloniex.com/support/api/
    string constant ORACLE_ARGUMENTS = "json(https://poloniex.com/public?command=returnTicker).USDT_ETH.last";
    
    function OraclePoloniex() public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}