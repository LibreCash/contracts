pragma solidity ^0.4.21;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/token/ERC20.sol";
import "./zeppelin/math/SafeMath.sol";


contract LibertyPreSale is Ownable {
    using SafeMath for uint256;

    // Date of start of pre-sale
    uint256 public constant dateStart = 1514764800;

    // Date of end of pre-sale (could end earlier if cap is reached)
    uint256 public constant dateEnd = 1515283200;

    // Max mount of ether allowed to collect during pre-sale
    uint256 public saleCap = 100 ether;

    // The flag indicates that ALL pre-sale actions are done
    // * payment is not accepted anymore
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

    event PaymentAccepted(address buyer, address recipient, uint256 amount);
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
            getTime() >= dateStart &&
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
        emit PaymentAccepted(msg.sender, recipient, weiToAccept);
        // If the buyer is new add him to `buyers` list
        if (raisedByAddress[recipient] == 0) {
            buyers.push(recipient);
        }
        raisedByAddress[recipient] = raisedByAddress[recipient].add(weiToAccept);
        fundsWallet.transfer(weiToAccept);
        if (weiToReturn > 0) {
            msg.sender.transfer(weiToReturn);
            emit ChangeReturned(msg.sender, weiToReturn);
        }
    }

    function distributeTokens(uint256 _limit) public onlyOwner {
        require(!isFinalized);
        require(
            getTime() >= dateEnd || 
            weiRaised >= saleCap
        );
        if (weiRaised > 0) {
            if (distributeIndex == 0) {
                require(token.balanceOf(address(this)) >= saleTokenAmount);
            }
            uint256 localLimit = distributeIndex + _limit;
            uint256 tokenPerWei = saleTokenAmount / weiRaised;
            while (distributeIndex < buyers.length && distributeIndex < localLimit) {
                address buyer = buyers[distributeIndex];
                uint256 _tokenAmount = tokenPerWei.mul(raisedByAddress[buyer]);
                token.transfer(buyer, _tokenAmount);
                distributeIndex += 1;
            }
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