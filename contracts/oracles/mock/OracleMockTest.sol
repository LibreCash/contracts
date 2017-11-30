pragma solidity ^0.4.10;
import "./OracleMockBase.sol";

contract OracleMockTest is OracleMockBase {
    function OracleMockTest() {
        oracleName = "Test (Mocked Oracle, 1000)";
        rate = 1000;
    }
}