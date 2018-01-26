pragma solidity ^0.4.17;

import "./OracleBase.sol";

/**
 * @title Bitstamp oracle.
 *
 * @dev https://www.bitstamp.net/.
 */
contract OracleBitstamp is OracleBase {
    // the comment is reserved for API documentation :)
    bytes32 constant ORACLE_NAME = "Bitstamp Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://www.bitstamp.net/api/v2/ticker/ethusd).last";
    
    /**
     * @dev Constructor.
     */
    function OracleBitstamp(address _bankAddress) OracleBase(_bankAddress) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}