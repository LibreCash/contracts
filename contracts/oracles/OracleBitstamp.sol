pragma solidity ^0.4.18;

import "./OracleBase.sol";


/**
 * @title Bitstamp oracle.
 *
 * @dev URL: https://www.bitstamp.net/
 * @dev API Docs: https://www.bitstamp.net/api/
 */
contract OracleBitstamp is OracleBase {
    bytes32 constant ORACLE_NAME = "Bitstamp Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://www.bitstamp.net/api/v2/ticker/ethusd).last";
    
    /**
     * @dev Constructor.
     */
    function OracleBitstamp(address bank) OracleBase(bank) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}