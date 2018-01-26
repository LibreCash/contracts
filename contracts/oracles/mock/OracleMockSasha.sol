pragma solidity ^0.4.17;
import "./OracleMockBase.sol";

contract OracleMockSasha is OracleMockBase {
    function OracleMockSasha() {
        oracleName = "Sasha (Mocked Oracle, 300000)";
        rate = 300000;
    }
}