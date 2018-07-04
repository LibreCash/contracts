pragma solidity ^0.4.23;

import "./OracleBase.sol";



/**
 * @title Poloniex oracle.
 *
 * @dev URL: https://poloniex.com/
 * @dev API Docs: https://poloniex.com/support/api/
 */
contract OraclePoloniex is OracleBase {
    bytes32 constant ORACLE_NAME = "Poloniex Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://poloniex.com/public?command=returnTicker).USDT_ETH.last";

    constructor(address bank) OracleBase(bank) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}
