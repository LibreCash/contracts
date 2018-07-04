pragma solidity ^0.4.23;
import "./OracleMockBase.sol";



/**
 * @title Mocked oracles contract for testing purposes.
 */
contract OracleMockLiza is OracleMockBase {
    constructor(address bank) OracleMockBase(bank) public {
        oracleName = "Liza (Mocked Oracle, 320000)";
        mockRate = 320000;
    }

}
