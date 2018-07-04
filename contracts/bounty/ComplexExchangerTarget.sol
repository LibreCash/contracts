pragma solidity ^0.4.23;

import "../ComplexExchanger.sol";
import { Target } from './Bounty.sol';


contract ComplexExchangerTarget is ComplexExchanger, Target {
    string public targetName = "ComplexExchanger";

    constructor (
        address _token,
        uint256 _buyFee,
        uint256 _sellFee,
        address _feed,
        uint256 _deadline,
        address _withdrawWallet
    ) public
    ComplexExchanger(_token, _buyFee, _sellFee, _feed, _deadline, _withdrawWallet) {

    }

    function checkInvariant(address _researcher) public view returns(bool) {
        bool wrongRates = (buyRate() == 0) || (sellRate() == 0) || (buyRate() > sellRate());
        return !wrongRates;
    }
}
