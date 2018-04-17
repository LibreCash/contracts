pragma solidity ^0.4.18;

import "./ComplexBankTarget.sol";
import "./LibreCashTarget.sol";
import { Bounty, Target } from "../zeppelin/Bounty.sol";

contract ComplexBankBounty is Bounty {
    address[] public oracles;

    function ComplexBankBounty(uint256 _deadline, address[] _oracles) Bounty(_deadline) {
        oracles = _oracles;
    }

    function createBankTargets(uint256 _buyFee, uint256 _sellFee) public beforeDeadline returns(address[]) {
        address libreCash;
        address complexBank;
        (libreCash, complexBank) = deployBankContracts(_buyFee, _sellFee, oracles);
        researchers[libreCash] = msg.sender;
        researchers[complexBank] = msg.sender;
        TargetCreated("LibreCash", msg.sender, libreCash);
        addTarget(libreCash);
        TargetCreated("ComplexBank", msg.sender, complexBank);
        addTarget(complexBank);
        address[] memory targets = new address[](2);
        targets[0] = libreCash;
        targets[1] = complexBank;
        return targets;
    }

    function deployBankContracts(uint256 _buyFee, uint256 _sellFee, address[] _oracles) internal returns(address, address) {
        LibreCashTarget libreCash = new LibreCashTarget();
        ComplexBankTarget complexBank = new ComplexBankTarget(libreCash, _buyFee, _sellFee, _oracles);
        libreCash.transferOwnership(complexBank);
        complexBank.claimOwnership();
        return (address(libreCash), address(complexBank));            
    }

    function eraseClaim() public {
        claimed = false;
    }
}