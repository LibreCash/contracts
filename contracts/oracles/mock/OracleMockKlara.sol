pragma solidity ^0.4.10;
import "./OracleMockBase.sol";

contract OracleMockKlara is OracleMockBase {
    bytes32 public oracleName = "Klara (Mocked Oracle, 28000)";
    uint rate = 28000;
}