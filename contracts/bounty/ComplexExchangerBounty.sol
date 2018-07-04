pragma solidity ^0.4.23;

import "./ComplexExchangerTarget.sol";
import "../token/LibreCash.sol";
import { Bounty } from './Bounty.sol';


contract ComplexExchangerBounty is Bounty {
    address public feed;

    constructor (uint256 _deadline, address _feed) Bounty(_deadline) public {
        feed = _feed;
    }

    function createExchangerTargets(uint256 _buyFee, uint256 _sellFee, uint256 _deadline, address _withdrawWallet)
        public
        beforeDeadline
        returns(address)
    {
        address libreCash;
        address complexExchanger;
        (libreCash, complexExchanger) = deployExchangerContracts(_buyFee, _sellFee, feed, _deadline, _withdrawWallet);
        researchers[complexExchanger] = msg.sender;
        emit TargetCreated("ComplexExchanger", msg.sender, complexExchanger);
        addTarget(complexExchanger, "ComplexExchanger");
        return complexExchanger;
    }

    function deployExchangerContracts(
        uint256 _buyFee, uint256 _sellFee, address _feed, uint256 _deadline, address _withdrawWallet
    ) internal returns(address, address) {
        LibreCash libreCash = new LibreCash();
        ComplexExchangerTarget complexExchanger = new ComplexExchangerTarget(
            libreCash, _buyFee, _sellFee, _feed, _deadline, _withdrawWallet);
        // we do not transfer cash ownership when deploy exchanger
        return (address(libreCash), address(complexExchanger));
    }
}
