pragma solidity ^0.4.18;


import "./payment/PullPayment.sol";
import "./lifecycle/Destructible.sol";


/**
 * @title Bounty
 * @dev This bounty will pay out to a researcher if they break invariant logic of the contract.
 */
contract Bounty is PullPayment {
  bool public claimed;
  mapping(address => address) public researchers;

  event TargetCreated(string description, address researcher, address createdAddress);

  /**
   * @dev Fallback function allowing the contract to receive funds, if they haven't already been claimed.
   */
  function() external payable {
    require(!claimed);
  }

  /**
   * @dev Create and deploy the target contract (extension of Target contract), and sets the
   * msg.sender as a researcher
   * @return A target contract
   */
  function createTargets(uint256 _buyFee, uint256 _sellFee) public returns(Target[]);

  /**
   * @dev Sends the contract funds to the researcher that proved the contract is broken.
   * @param target contract
   */
  function claim(Target target) public {
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

  /**
   * @dev Internal function to deploy the target contract.
   * @return A target contract address
   */
  function deployContracts(uint256 _buyFee, uint256 _sellFee, address[] _oracles) internal returns(address, address);

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