pragma solidity ^0.4.10;
import "./OracleMockBase.sol";

contract OracleMockTest is OracleMockBase {
    function OracleMockTest() {
        oracleName = "Test (Mocked Oracle, 28000)";
        rate = 100;
        minimalUpdateInterval = 0;
    }
}