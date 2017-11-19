pragma solidity ^0.4.11;

import "./OracleBase.sol";

/**
 * @title GDAX oracle.
 *
 * @dev https://www.gdax.com/.
 */
contract OracleGDAX is OracleBase {
    // the comment is reserved for API documentation :)
    bytes32 constant ORACLE_NAME = "GDAX Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://api.gdax.com/products/ETH-USD/ticker).price";
    
    /**
     * @dev Constructor.
     */
    function OracleGDAX(address _bankAddress) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
        bankAddress = _bankAddress;
    }
}