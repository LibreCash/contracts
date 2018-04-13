pragma solidity ^0.4.18;

import "./ComplexBankTarget.sol";
import "./LibreCashTarget.sol";
import { Bounty, Target } from "../zeppelin/Bounty.sol";

contract ComplexBankBounty is Bounty {
    address[] public oracles;

    function ComplexBankBounty(address[] _oracles) {
        oracles = _oracles;
    }

    function createTargets(uint256 _buyFee, uint256 _sellFee) public returns(Target[]) {
        address libreCash;
        address complexBank;
        (libreCash, complexBank) = deployContracts(_buyFee, _sellFee, oracles);
        researchers[libreCash] = msg.sender;
        researchers[complexBank] = msg.sender;
        TargetCreated("LibreCash", msg.sender, libreCash);
        TargetCreated("ComplexBank", msg.sender, complexBank);
        Target[] memory targets = new Target[](2);
        // just to verify it fits the interface
        targets[0] = Target(libreCash);
        targets[1] = Target(complexBank);
        return targets;
    }

    function deployContracts(uint256 _buyFee, uint256 _sellFee, address[] _oracles) internal returns(address, address) {
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