pragma solidity ^0.4.18;

import "./payment/PullPayment.sol";


/**
 * @title Bounty
 * @dev This bounty will pay out to a researcher if they break invariant logic of the contract.
 */
contract Bounty is PullPayment {
  bool public claimed;
  uint256 public deadline;
  mapping(address => address) public researchers;

  event TargetCreated(string description, address researcher, address createdAddress);

  function Bounty(uint256 _deadline) {
    deadline = _deadline;
  }

  /**
   * @dev Fallback function allowing the contract to receive funds, if they haven't already been claimed.
   */
  function() external payable {
    require(!claimed);
  }

  /**
   * @dev Sends the contract funds to the researcher that proved the contract is broken.
   * @param target contract
   */
  function claim(Target target) public {
    require(now <= deadline);
    address researcher = researchers[target];
    require(researcher != 0);
    // Check Target contract invariants
    require(!target.checkInvariant(researcher));
    asyncSend(researcher, this.balance);
    claimed = true;
  }

  function suicideTarget(address _target) public {
    require(researchers[_target] == msg.sender);
    Target(_target)._suicide(msg.sender);
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