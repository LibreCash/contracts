pragma solidity ^0.4.17;

import "./OracleBase.sol";

/**
 * @title Bitfinex oracle.
 *
 * @dev https://www.bitfinex.com.
 */
contract OracleBitfinex is OracleBase {
    // https://bitfinex.readme.io/v1/reference#rest-public-ticker
    bytes32 constant ORACLE_NAME = "Bitfinex Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://api.bitfinex.com/v1/pubticker/ethusd).last_price";
    
    /**
     * @dev Constructor.
     */
    function OracleBitfinex(address _bankAddress) OracleBase(_bankAddress) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}