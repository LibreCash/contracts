pragma solidity ^0.4.17;
import "./OracleMockBase.sol";

contract OracleMockKlara is OracleMockBase {
    function OracleMockKlara() {
        oracleName = "Klara (Mocked Oracle, 280000)";
        rate = 280000;
    }
}