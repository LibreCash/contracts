pragma solidity ^0.4.18;

import "./payment/PullPayment.sol";
import "./ownership/Ownable.sol";


/**
 * @title Bounty
 * @dev This bounty will pay out to a researcher if they break invariant logic of the contract.
 */
contract Bounty is PullPayment, Ownable {
  bool public claimed;
  uint256 public deadline;
  mapping(address => address) public researchers;
  mapping(address => address[]) private targets;

  event TargetCreated(string description, address researcher, address createdAddress);
  event TargetDestroyed(address researcher, address destroyedAddress);

  modifier beforeDeadline() {
    require(now <= deadline);
    _;
  }

  modifier afterDeadline() {
    require(now > deadline);
    _;
  }

  function Bounty(uint256 _deadline) {
    deadline = _deadline;
  }

  function getMyTargets() public view returns(address[]) {
    return targets[msg.sender];
  }

  function addTarget(address _target, string _description) internal {
    targets[msg.sender].push(_target);
  }

  function deleteTarget(uint256 _id) internal {
    TargetDestroyed(msg.sender, targets[msg.sender][_id]);
    targets[msg.sender][_id] = targets[msg.sender][targets[msg.sender].length - 1];
    targets[msg.sender].length--;
  }

  /**
   * @dev Fallback function allowing the contract to receive funds, if they haven't already been claimed.
   */
  function() external payable {
    require(!claimed);
  }

  function ownerWithdraw() public afterDeadline onlyOwner {
    owner.transfer(address(this).balance);
  }

  /**
   * @dev Sends the contract funds to the researcher that proved the contract is broken.
   * @param target contract
   */
  function claim(Target target) public beforeDeadline {
    address researcher = researchers[target];
    require(researcher != 0);
    // Check Target contract invariants
    require(!target.checkInvariant(researcher));
    asyncSend(researcher, this.balance);
    claimed = true;
  }

  function suicideTarget(uint256 _id) public {
    require(targets[msg.sender][_id] != 0);
    Target(targets[msg.sender][_id])._suicide(msg.sender);
    deleteTarget(_id);
  }
}


/**
 * @title Target
 * @dev Your main contract should inherit from this class and implement the checkInvariant method.
 */
contract Target {
  address bounty;

  function Target() public {
    // owner can be changed^ so we need to fix bounty - the contract we were deployed by
    bounty = msg.sender;
  }

  modifier onlyBounty() {
    require(msg.sender == bounty);
    _;
  }

   /**
    * @dev Checks all values a contract assumes to be true all the time. If this function returns
    * false, the contract is broken in some way and is in an inconsistent state.
    * In order to win the bounty, security researchers will try to cause this broken state.
    * @return True if all invariant values are correct, false otherwise.
    */
  function checkInvariant(address _researcher) public view returns(bool);

  function _suicide(address _beneficiar) public onlyBounty {
    selfdestruct(_beneficiar);
  }
}