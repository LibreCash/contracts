pragma solidity ^0.4.18;

import "./ComplexBankTarget.sol";
import "./LibreCashTarget.sol";
import { Bounty, Target } from "../zeppelin/Bounty.sol";


contract ComplexBankBounty is Bounty {
    address public feed;

    function ComplexBankBounty(uint256 _deadline, address _feed) Bounty(_deadline) public {
        feed = _feed;
    }

    function createBankTargets(uint256 _buyFee, uint256 _sellFee) public beforeDeadline returns(address, address) {
        address libreCash;
        address complexBank;
        (libreCash, complexBank) = deployBankContracts(_buyFee, _sellFee, feed);
        researchers[libreCash] = msg.sender;
        researchers[complexBank] = msg.sender;
        TargetCreated("LibreCash", msg.sender, libreCash);
        addTarget(libreCash, "LibreCash");
        TargetCreated("ComplexBank", msg.sender, complexBank);
        addTarget(complexBank, "ComplexBank");
        return (libreCash, complexBank);
    }

    function deployBankContracts(uint256 _buyFee, uint256 _sellFee, address _feed) internal returns(address, address) {
        LibreCashTarget libreCash = new LibreCashTarget();
        ComplexBankTarget complexBank = new ComplexBankTarget(libreCash, _buyFee, _sellFee, _feed);
        libreCash.transferOwnership(complexBank);
        complexBank.claimOwnership();
        return (address(libreCash), address(complexBank));            
    }
}