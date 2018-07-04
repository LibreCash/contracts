pragma solidity ^0.4.23;
import "./BountyOracleBase.sol";


contract BountyOracle1 is BountyOracleBase {
    constructor()  public {
        oracleName = "Bounty Oracle 1";
        mockRate = 320000;
    }
}
