pragma solidity ^0.4.11;

contract OracleI {
    function updateRate() external returns (bool);
    //function name() constant public returns (bytes32);
    bytes32 public name;
    function setBank(address _bankAddress) public;
    //function rate() public returns (uint256);
    uint256 public rate;
    bytes32 public queryId;
    //function queryId() public returns (bytes32);
    function clearState() public;
    //function updateTime() public returns (uint256);
    uint256 public updateTime;
    //function hasReceivedRate() public view returns (bool);
}
