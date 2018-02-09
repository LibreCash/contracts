pragma solidity ^0.4.17;

import "./OracleBase.sol";

contract OracleCoinmarketcap is OracleBase {
    bytes32 constant ORACLE_NAME = "CoinMarketCap Oraclize";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    // https://coinmarketcap.com/api/
    string constant ORACLE_ARGUMENTS = "json(https://api.coinmarketcap.com/v1/ticker/ethereum/?convert=USD).[0].price_usd";
    
    function OracleCoinmarketcap(address _bankAddress) OracleBase(_bankAddress) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}