pragma solidity ^0.4.18;

import "./OracleBase.sol";


/**
 * @title Bitfinex oracle.
 *
 * @dev URL: https://www.bitfinex.com
 * @dev API Docs: https://bitfinex.readme.io/v1/reference#rest-public-ticker
 */
contract OracleBitfinex is OracleBase {
    bytes32 constant ORACLE_NAME = "Bitfinex Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://api.bitfinex.com/v1/pubticker/ethusd).last_price";
    
    /**
     * @dev Constructor.
     */
    function OracleBitfinex(address bank) OracleBase(bank) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}