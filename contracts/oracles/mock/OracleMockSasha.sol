pragma solidity ^0.4.10;
import "./OracleMockBase.sol";

contract OracleMockSasha is OracleMockBase {
    bytes32 public oracleName = "Sasha (Mocked Oracle, 30000)";
    uint rate = 30000;
}