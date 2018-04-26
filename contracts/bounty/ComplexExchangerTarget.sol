pragma solidity ^0.4.18;

import "../ComplexExchanger.sol";
import { Target } from "../zeppelin/Bounty.sol";


contract ComplexExchangerTarget is ComplexExchanger, Target {
    string public targetName = "ComplexExchanger";
    bool public tempHacked = false;

    function tempHack(bool _val) public payable {
        tempHacked = _val;
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
        bool wrongRates = (buyRate == 0) || (sellRate == 0) || (buyRate > sellRate) || tempHacked;
        return !wrongRates;
    }
}