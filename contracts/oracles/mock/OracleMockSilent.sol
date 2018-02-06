pragma solidity ^0.4.17;
import "./OracleMockBase.sol";

/**
 * @title Mocked silent oracle contract for testing purposes.
 */
contract OracleSilent is OracleMockBase {
    function OracleMockTest() {
        oracleName = "Silent Oracle";
        mockRate = 0;
    }

    function updateRate() external returns(bool) {
        updateTime = now;
        waitQuery = true;
        return true;
    }
}