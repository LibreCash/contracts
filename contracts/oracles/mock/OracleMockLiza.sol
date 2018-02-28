pragma solidity ^0.4.18;
import "./OracleMockBase.sol";

contract OracleMockLiza is OracleMockBase {
    function OracleMockLiza() {
        oracleName = "Liza (Mocked Oracle, 320000)";
        mockRate = 320000;
    }

}