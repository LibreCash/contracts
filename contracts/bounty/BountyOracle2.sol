pragma solidity ^0.4.23;
import "./BountyOracleBase.sol";


contract BountyOracle2 is BountyOracleBase {
    constructor()  public {
        oracleName = "Bounty Oracle 2";
        mockRate = 280000;
    }
}
