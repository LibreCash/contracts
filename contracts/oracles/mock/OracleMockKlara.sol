pragma solidity ^0.4.18;
import "./OracleMockBase.sol";


/**
 * @title Mocked oracles contract for testing purposes.
 */
contract OracleMockKlara is OracleMockBase {
    function OracleMockKlara(address bank) OracleMockBase(bank) public {
        oracleName = "Klara (Mocked Oracle, 280000)";
        mockRate = 280000;
    }
}