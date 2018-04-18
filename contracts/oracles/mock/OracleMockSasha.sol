pragma solidity ^0.4.18;
import "./OracleMockBase.sol";

/**
 * @title Mocked oracles contract for testing purposes.
 */
contract OracleMockSasha is OracleMockBase {
    function OracleMockSasha() public {
        oracleName = "Sasha (Mocked Oracle, 300000)";
        mockRate = 300000;
    }
}