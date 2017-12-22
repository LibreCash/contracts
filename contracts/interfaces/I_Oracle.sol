pragma solidity ^0.4.11;

contract OracleI {
    bytes32 public oracleName;
    bytes32 public oracleType;
    uint256 public rate;
    bool public waitQuery;
    uint256 public updateTime;
    uint256 public callbackTime;
    function getPrice() view public returns (uint);
    function setBank(address _bankAddress) public;
    function updateRate() external returns (bool);
    function clearState() public;
}
