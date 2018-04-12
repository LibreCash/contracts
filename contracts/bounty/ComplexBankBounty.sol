pragma solidity ^0.4.18;

import "./ComplexBankTarget.sol";
import { Bounty, Target } from "../zeppelin/Bounty.sol";

contract ComplexBankBounty is Bounty {
    address[] public oracles;

    function ComplexBankBounty(address[] _oracles) {
        oracles = _oracles;
    }

    function createTarget(address _token, uint256 _buyFee, uint256 _sellFee) public returns(Target) {
        Target target = Target(deployContract(_token, _buyFee, _sellFee, oracles));
        researchers[target] = msg.sender;
        TargetCreated(target);
        return target;
    }

    function deployContract(address _token, uint256 _buyFee, uint256 _sellFee, address[] _oracles) internal returns(address) {
        return new ComplexBankTarget(_token, _buyFee, _sellFee, _oracles);
    }

    function eraseClaim() public {
        claimed = false;
    }
}