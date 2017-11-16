pragma solidity ^0.4.11;

interface OracleI {
    function updateRate() external returns (bool);
    function getName() constant public returns (bytes32);
    function setBank(address _bankAddress) public;
    function getRate() public returns (uint256);
    function getQueryId() public returns (bytes32);
    function clearState() public;
    function getUpdateTime() public returns (uint256);
    //function hasReceivedRate() public view returns (bool);
}
