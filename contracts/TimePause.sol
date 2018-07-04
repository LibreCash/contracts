pragma solidity ^0.4.23;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';


/**
 * @title TimePause
 * @dev Contract which allows children to implement an emergency stop mechanism.
 */
contract TimePause is Ownable {
  using SafeMath for uint256;

  event Pause(uint256 from, uint256 to);

  uint256 public pauseStart;
  uint256 pauseEnd;
  uint256 constant MIN_PAUSE = 3 minutes;
  uint256 constant MAX_PAUSE = 10 minutes;
  uint256 constant PAUSE_PERIOD = 10 hours; // min period between pauses

  function paused() public view returns (bool) {
      return now >= pauseStart && now <= pauseEnd;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused());
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused());
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause(uint256 interval) onlyOwner whenNotPaused public {
    require(interval >= MIN_PAUSE && interval <= MAX_PAUSE && pauseEnd.add(PAUSE_PERIOD) <= now);
    pauseStart = now;
    pauseEnd = now.add(interval);
    emit Pause(pauseStart, pauseEnd);
  }

  /**
   * @dev called by the owner to unpause contract
   */
  function unpause() onlyOwner whenPaused public {
    pauseStart = pauseEnd.add(1); // make pauseStart later then pauseEnd so pause condition never be true
    // also we need to save pauseEnd to keep intervals
  }
}
