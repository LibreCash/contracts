pragma solidity ^0.4.10;
import "./OracleMockBase.sol";

contract OracleMockLiza is OracleMockBase {
    bytes32 public oracleName = "Liza (Mocked Oracle, 32000)";
    uint rate = 32000;
}