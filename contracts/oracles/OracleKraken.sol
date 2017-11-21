pragma solidity ^0.4.11;

import "./OracleBase.sol";

/**
 * @title Kraken oracle.
 *
 * @dev https://www.kraken.com/.
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
    function OracleKraken(address _bankAddress) OracleBase(_bankAddress) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}