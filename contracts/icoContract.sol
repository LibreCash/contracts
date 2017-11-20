pragma solidity ^0.4.15;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract LibertyPreSale is Ownable {
    using SafeMath for uint256;

    // Date of start of pre-sale
    uint256 public constant dateStart = 1514764800;

    // Date of end of pre-sale (could end earlier if cap is reached)
    uint256 public constant dateEnd = 1515283200;

    // Max mount of ether allowed to collect during pre-sale
    uint256 public saleCap = 100 * (10**18); 

    // The flag indicates that ALL pre-sale actions is done
    // * payment is not accpepted anymore
    // * tokens are distributed
    bool public isFinalized = false;

    // How much ether collected during pre-sale
    uint256 public weiRaised = 0;

    // The address of wallet to redirect incoming ether
    address public fundsWallet = 0x0;

    // Address of token
    ERC20 public token = ERC20(0x0);

    // Number of tokens to distribute when pre-sale finished 
    uint256 public saleTokenAmount = 5 * (10**6) * (10**18);

    // Numbers of ether raised from each buyer
    mapping(address => uint256) public raisedByAddress;

    // List of buyers
    address[] buyers;

    // Number of buyer in `buyers` list to start distributing token
    // in next call to `distributeTokens()`
    uint256 distributeIndex = 0;

    /*
     * Events
     */

    event PaymentAcepted(address buyer, address recipient, uint256 amount);
    event ChangeReturned(address buyer, uint256 amount);
    // For debugging
    event Log(string _msg, uint256 value);

    /*
     * Public Methods
     */

    function LibertyPreSale(address _token, address _fundsWallet) public {
        require(_fundsWallet != 0x0);
        require(_token != 0x0);
        token = ERC20(_token);
        fundsWallet = _fundsWallet;
    }

    function() public payable {
        buyTokens(msg.sender);
    }

    function buyTokens(address recipient) public payable {
        require(
            getTime() < dateEnd &&
            weiRaised < saleCap &&
            msg.value > 0
        );
        uint256 weiToAccept = 0;
        uint256 weiToReturn = 0;
        if (weiRaised.add(msg.value) > saleCap) {
            weiToAccept = saleCap.sub(weiRaised);
            weiToReturn = msg.value - weiToAccept;
        } else {
            weiToAccept = msg.value;
            weiToReturn = 0;
        }
        weiRaised = weiRaised.add(weiToAccept);
        PaymentAcepted(msg.sender, recipient, weiToAccept);
        // If the buyer is new add him to `buyers` list
        if (raisedByAddress[recipient] == 0) {
            buyers.push(recipient);
        }
        raisedByAddress[recipient] = raisedByAddress[recipient].add(weiToAccept);
        fundsWallet.transfer(weiToAccept);
        if (weiToReturn > 0) {
            msg.sender.transfer(weiToReturn);
            ChangeReturned(msg.sender, weiToReturn);
        }
    }

    function distributeTokens(uint256 _limit) public onlyOwner {
        require(!isFinalized);
        require(
            getTime() >= dateEnd || 
            weiRaised >= saleCap
        );
        if (distributeIndex == 0) {
            require(token.balanceOf(address(this)) == saleTokenAmount);
        }
        uint256 localLimit = distributeIndex + _limit;
        while (distributeIndex < buyers.length && distributeIndex < localLimit) {
            address buyer = buyers[distributeIndex];
            uint256 _tokenAmount = saleTokenAmount.mul(raisedByAddress[buyer]).div(weiRaised);
            token.transfer(buyer, _tokenAmount);
            distributeIndex += 1;
        }
        if (distributeIndex == buyers.length) {
            isFinalized = true;
        }
    }

    /* 
     * Internal Methods
     */

    function getTime() internal returns (uint256) {
        return now;
    }

}
