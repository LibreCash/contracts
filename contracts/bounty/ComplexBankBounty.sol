pragma solidity ^0.4.18;

import "./ComplexBankTarget.sol";
import { Bounty, Target } from "../zeppelin/Bounty.sol";

contract ComplexBankBounty is Bounty {
  function createTarget(address _token, uint256 _buyFee, uint256 _sellFee, address[] _oracles) public returns(Target) {
    Target target = Target(deployContract(_token, _buyFee, _sellFee, _oracles));
    researchers[target] = msg.sender;
    TargetCreated(target);
    return target;
  }

  function deployContract(address _token, uint256 _buyFee, uint256 _sellFee, address[] _oracles) internal returns(address) {
    return new ComplexBankTarget(_token, _buyFee, _sellFee, _oracles);
  }
}