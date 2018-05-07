pragma solidity ^0.4.18;

import "./OracleBase.sol";


/**
 * @title Coinmarketcap oracle.
 *
 * @dev URL: https://coinmarketcap.com/
 * @dev API Docs: https://coinmarketcap.com/api/
 */
contract OracleCoinmarketcap is OracleBase {
    bytes32 constant ORACLE_NAME = "CoinMarketCap Oraclize";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    // https://coinmarketcap.com/api/
    string constant ORACLE_ARGUMENTS = "json(https://api.coinmarketcap.com/v1/ticker/ethereum/?convert=USD).[0].price_usd";
    
    function OracleCoinmarketcap(address bank) OracleBase(bank) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}