pragma solidity ^0.4.11;

import "./zeppelin/ownership/Ownable.sol";
import "./OracleBase.sol";

contract OraclePoloniex is OracleBase {
    bytes32 constant ORACLE_NAME = "Poloniex Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    // https://poloniex.com/support/api/
    string constant ORACLE_ARGUMENTS = "json(https://poloniex.com/public?command=returnTicker).USDT_ETH.last";
    
    function OraclePoloniex(address _bankContract) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
        bankContractAddress = _bankContract;
        updateCosts();
        //update();
    }
    

    // for tests
    function getRate() public returns(uint256) {
        return rate;
    }
    function setRate(uint256 _rate) public {
        rate = _rate;
    }

    
    function donate() payable { }
    // Sending ether directly to the contract invokes buy() and assigns tokens to the sender 


}