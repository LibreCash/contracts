pragma solidity ^0.4.23;

import "./OracleBase.sol";



/**
 * @title Gemini oracle.
 *
 * @dev URL: https://gemini.com/
 * @dev API Docs: https://docs.gemini.com/rest-api/
 */
contract OracleGemini is OracleBase {
    // the comment is reserved for API documentation :)
    bytes32 constant ORACLE_NAME = "Gemini Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://api.gemini.com/v1/pubticker/ethusd).last";

    /**
     * @dev Constructor.
     */
    constructor(address bank) OracleBase(bank) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}
