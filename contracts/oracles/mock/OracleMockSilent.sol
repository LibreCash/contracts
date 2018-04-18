pragma solidity ^0.4.18;
import "./OracleMockBase.sol";

/**
 * @title Mocked silent oracle contract for testing purposes.
 */
contract OracleSilent is OracleMockBase {
    function OracleMockTest() public {
        oracleName = "Silent Oracle";
        mockRate = 0;
    }

    function updateRate() external returns(bool) {
        updateTime = now;
        waitQuery = true;
        return true;
    }
}