pragma solidity ^0.4.23;
import "./OracleMockBase.sol";



/**
 * @title Mocked oracles contract for testing purposes.
 */
contract OracleMockTest is OracleMockBase {
    constructor(address bank) OracleMockBase(bank) public {
        oracleName = "Test (Mocked Oracle, 1000)";
        mockRate = 1000;
    }
}
