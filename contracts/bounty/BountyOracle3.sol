pragma solidity ^0.4.23;
import "./BountyOracleBase.sol";


contract BountyOracle3 is BountyOracleBase {
    function constructor()  public {
        oracleName = "Bounty Oracle 3";
        mockRate = 333000;
    }
}
