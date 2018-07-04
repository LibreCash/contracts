pragma solidity ^0.4.23;
import "./OracleMockBase.sol";



/**
 * @title Mocked oracles contract for testing purposes.
 */
contract OracleMockKlara is OracleMockBase {
    constructor(address bank) OracleMockBase(bank) public {
        oracleName = "Klara (Mocked Oracle, 280000)";
        mockRate = 280000;
    }
}
