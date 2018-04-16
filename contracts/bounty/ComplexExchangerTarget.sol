pragma solidity ^0.4.18;

import "../ComplexExchanger.sol";
import { Target } from "../zeppelin/Bounty.sol";


contract ComplexExchangerTarget is ComplexExchanger, Target {
    uint256 public bountyIs666 = 0;

    function setBountyIs666(uint256 _val) public payable {
        bountyIs666 = _val;
    }

    function ComplexExchangerTarget(
        address _token,
        uint256 _buyFee,
        uint256 _sellFee,
        address[] _oracles,
        uint256 _deadline,
        address _withdrawWallet
    )
        ComplexExchanger(_token, _buyFee, _sellFee, _oracles, _deadline, _withdrawWallet) {
            // initial values
            sellRate = 1000;
            buyRate = 1000;
    }

    function checkInvariant(address _researcher) public view returns(bool) {
        bool wrongRates = (buyRate == 0) || (sellRate == 0) || (buyRate > sellRate) || (bountyIs666 == 666);
        return !wrongRates;
    }
}