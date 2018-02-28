pragma solidity ^0.4.18;

import "./OracleBase.sol";

/**
 * @title Kraken oracle.
 *
 * @dev URL: https://www.kraken.com/
 * @dev API Docs: https://www.kraken.com/help/api
 */
contract OracleKraken is OracleBase {
    // the comment is reserved for API documentation :)
    bytes32 constant ORACLE_NAME = "Kraken Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0";
    
    /**
     * @dev Constructor.
     */
    function OracleKraken() public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}