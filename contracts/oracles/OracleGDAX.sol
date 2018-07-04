pragma solidity ^0.4.23;

import "./OracleBase.sol";



/**
 * @title GDAX oracle.
 *
 * @dev URL: https://www.gdax.com/
 * @dev API Docs: https://docs.gdax.com
 */
contract OracleGDAX is OracleBase {
    bytes32 constant ORACLE_NAME = "GDAX Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://api.gdax.com/products/ETH-USD/ticker).price";

    /**
     * @dev Constructor.
     */
    constructor(address bank) OracleBase(bank) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}
