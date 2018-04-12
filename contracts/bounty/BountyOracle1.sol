pragma solidity ^0.4.18;
import "./BountyOracleBase.sol";

contract BountyOracle1 is BountyOracleBase {
    function BountyOracle1() {
        oracleName = "Bounty Oracle 1";
        mockRate = 320000;
    }
}