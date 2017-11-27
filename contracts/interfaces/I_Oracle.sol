pragma solidity ^0.4.11;

contract OracleI {
    bytes32 public oracleName;
    uint256 public rate;
    bytes32 queryId;
    bool public waitQuery;
    uint256 public updateTime;
    function getPrice() view public returns (uint);
    function setBank(address _bankAddress) public;
    function updateRate() external returns (bool);
    function clearState() public;
}
