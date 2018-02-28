pragma solidity ^0.4.18;

import "./LibertyPreSale.sol";

contract LibertyPreSaleMock is LibertyPreSale {
    uint256 mockTime = 0;

    function LibertyPreSaleMock(address _token, address _fundsWallet)
        LibertyPreSale(_token, _fundsWallet)
    {
        // emptiness
    }

    // Debug method to redefine current time
    function setTime(uint256 _time) public {
        mockTime = _time;
    }

    function getTime() internal returns (uint256) {
        if (mockTime != 0) {
            return mockTime;
        } else {
            return now;
        } 
    }
}