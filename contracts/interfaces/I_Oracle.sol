pragma solidity ^0.4.11;

interface OracleI {
    function updateRate() external returns (bool);
    function name() constant public returns (bytes32);
    function setBank(address _bankAddress) public;
    function rate() public returns (uint256);
    function queryId() public returns (bytes32);
    function clearState() public;
    function updateTime() public returns (uint256);
    //function hasReceivedRate() public view returns (bool);
}
