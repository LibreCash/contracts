pragma solidity ^0.4.17;
import "./OracleMockBase.sol";

contract OracleMockLiza is OracleMockBase {
    function OracleMockLiza() {
        oracleName = "Liza (Mocked Oracle, 320000)";
        rate = 320000;
    }

}