pragma solidity ^0.4.23;
import "./OracleMockBase.sol";



/**
 * @title Mocked silent oracle contract for testing purposes.
 */
contract OracleSilent is OracleMockBase {
    constructor (address bank) OracleMockBase(bank) public {
        oracleName = "Silent Oracle";
        mockRate = 0;
    }

    function updateRate(uint256 customGasPrice) external returns(bool) {
        updateTime = now;
        waitQuery = true;
        return true;
    }
}
