pragma solidity ^0.4.11;

import "./LocalOracleBase.sol";

contract LocalOracle2 is LocalOracleBase {
    /**
     * @dev Constructor.
     */
    function LocalOracle2() {
        rateData = "30455";
    }
}