pragma solidity ^0.4.23;

import "./LibertyPreSale.sol";


contract LibertyPreSaleMock is LibertyPreSale {
    uint256 mockTime = 0;

    constructor(address _token, address _fundsWallet)
        LibertyPreSale(_token, _fundsWallet)
     public {
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
