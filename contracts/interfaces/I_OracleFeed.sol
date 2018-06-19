pragma solidity ^0.4.23;


contract OracleFeedI {
    /* Rate calc & init  params */
    function requestRates() public payable;
    function calcRates() public;

    /* Data getters */
    function getOracleData(address _address) public view returns (bytes32, bytes32, uint256, bool, uint256, address);
    uint256 buyRate;
    uint256 sellRate;
}