pragma solidity ^0.4.18;
import "./BountyOracleBase.sol";


contract BountyOracle3 is BountyOracleBase {
    function BountyOracle3()  public {
        oracleName = "Bounty Oracle 3";
        mockRate = 333000;
    }
}