pragma solidity ^0.4.11;

import "./LocalOracleBase.sol";

contract LocalOracle3 is LocalOracleBase {
    /**
     * @dev Constructor.
     */
    function LocalOracle3() {
        rateData = "29999";
    }
}