pragma solidity ^0.4.11;

import "./LocalOracleBase.sol";

contract LocalOracle1 is LocalOracleBase {
    /**
     * @dev Constructor.
     */
    function LocalOracle1() {
        rateData = "29677";
    }
}