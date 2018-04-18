pragma solidity ^0.4.18;
import "./OracleMockBase.sol";

/**
 * @title Mocked oracles contract for testing purposes.
 */
contract OracleMockLiza is OracleMockBase {
    function OracleMockLiza() public {
        oracleName = "Liza (Mocked Oracle, 320000)";
        mockRate = 320000;
    }

}