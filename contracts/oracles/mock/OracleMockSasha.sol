pragma solidity ^0.4.18;
import "./OracleMockBase.sol";

contract OracleMockSasha is OracleMockBase {
    function OracleMockSasha() {
        oracleName = "Sasha (Mocked Oracle, 300000)";
        mockRate = 300000;
    }
}