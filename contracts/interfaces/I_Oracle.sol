pragma solidity ^0.4.11;

interface OracleI {
    function updateRate() external returns (bytes32);
    function getName() constant public returns (bytes32);
    function setBank(address _bankAddress) public;
    function hasReceivedRate() public view returns (bool);
}
