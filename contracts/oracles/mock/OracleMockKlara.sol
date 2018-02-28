pragma solidity ^0.4.18;
import "./OracleMockBase.sol";

contract OracleMockKlara is OracleMockBase {
    function OracleMockKlara() {
        oracleName = "Klara (Mocked Oracle, 280000)";
        mockRate = 280000;
    }
}