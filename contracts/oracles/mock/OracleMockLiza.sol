pragma solidity ^0.4.10;
import "./OracleMockBase.sol";

contract OracleMockLiza is OracleMockBase {
    function OracleMockLiza() {
        oracleName = "Liza (Mocked Oracle, 32000)";
        rate = 32000;
    }

}