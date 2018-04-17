pragma solidity ^0.4.18;

import "./ComplexExchangerTarget.sol";
import "../token/LibreCash.sol";
import { Bounty, Target } from "../zeppelin/Bounty.sol";

contract ComplexExchangerBounty is Bounty {
    address[] public oracles;

    function ComplexExchangerBounty(uint256 _deadline, address[] _oracles) Bounty(_deadline) {
        oracles = _oracles;
    }

    function createExchangerTargets(uint256 _buyFee, uint256 _sellFee, uint256 _deadline, address _withdrawWallet)
        public
        beforeDeadline
        returns(address)
    {
        address libreCash;
        address complexExchanger;
        (libreCash, complexExchanger) = deployExchangerContracts(_buyFee, _sellFee, oracles, _deadline, _withdrawWallet);
        researchers[complexExchanger] = msg.sender;
        TargetCreated("ComplexExchanger", msg.sender, complexExchanger);
        addTarget(complexExchanger);
        return complexExchanger;
    }

    function deployExchangerContracts(
        uint256 _buyFee, uint256 _sellFee, address[] _oracles, uint256 _deadline, address _withdrawWallet
    ) internal returns(address, address) {
        LibreCash libreCash = new LibreCash();
        ComplexExchangerTarget complexExchanger = new ComplexExchangerTarget(
            libreCash, _buyFee, _sellFee, _oracles, _deadline, _withdrawWallet);
        // we do not transfer cash ownership when deploy exchanger
        return (address(libreCash), address(complexExchanger)); 
    }

    function eraseClaim() public {
        claimed = false;
    }
}