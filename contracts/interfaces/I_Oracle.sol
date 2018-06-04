pragma solidity ^0.4.18;


contract OracleI {
    bytes32 public oracleName;
    bytes16 public oracleType;
    uint256 public rate;
    bool public waitQuery;
    uint256 public updateTime;
    uint256 public callbackTime;
    function getPrice() public view returns (uint);
    function setBank(address _bankAddress) public;
    function setGasPrice(uint256 _price) public;
    function setGasLimit(uint256 _limit) public;
    function updateRate(uint256 customGasPrice) external returns (bool);
}
