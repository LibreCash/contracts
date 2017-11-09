pragma solidity ^0.4.10;
import "./OracleMockBase.sol";

contract OracleMockKlara is OracleMockBase {
    function OracleMockKlara() {
        oracleName = "Klara (Mocked Oracle, 28000)";
        rate = 28000;
    }
}