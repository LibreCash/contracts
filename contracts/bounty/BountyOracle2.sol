pragma solidity ^0.4.18;
import "./BountyOracleBase.sol";


contract BountyOracle2 is BountyOracleBase {
    function BountyOracle2() {
        oracleName = "Bounty Oracle 2";
        mockRate = 280000;
    }
}