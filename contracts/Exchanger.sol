pragma solidity ^0.4.11;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/token/StandardToken.sol";
import "./zeppelin/token/BurnableToken.sol";


contract BurnableERC20 is BurnableToken, StandardToken {}

/**
 * @title Token exchanger contract.
 *
 * @dev ERC20 token exchanger contract for an ICO.
 */
contract Exchanger is Ownable {
    using SafeMath for uint;

    address public supplyTokenAddress = 0x0;
    address public collectingTokenAddress = 0x0;
    StandardToken private supplyToken;
    BurnableERC20 private collectingToken;
    uint constant RATE_MULTIPLIER = 10**9;
    uint public rate = 10**9; // 10**9 / RATE_MULTIPLIER = 1

    event NewCollectingToken(address oldTokenContract, address newTokenContract);
    event NewRate(uint oldRate, uint newRate);
    event Deposit(address tokenSender, uint tokenAmount, address tokenContract);
    event ExchangeRequest(address tokenSender, uint tokenAmount, address tokenContract);
    event SupplySent(address tokenBeneficiar, uint tokenAmount, address tokenContract);

    modifier tokens {
        require((msg.sender == supplyTokenAddress) || (msg.sender == collectingTokenAddress));
        _;
    }

    /**
     * @dev Allows the owner to set new exchange rate.
     * @param _rate The new rate.
     */
    function setRate(uint _rate) public onlyOwner {
        require(_rate != 0);
        NewRate(rate, _rate);
        rate = _rate;
    }

    /**
     * @dev Allows the owner to set the supply token address (can be set only once).
     * @param _address The contract address.
     */
    function setSupplyTokenOnce(address _address) public onlyOwner {
        require(supplyTokenAddress == 0x0);
        require(_address != collectingTokenAddress);
        require(_address != 0x0);
        supplyTokenAddress = _address;
        supplyToken = StandardToken(_address);
    }

    /**
     * @dev Allows the owner to set the collecting token address.
     * @param _address The contract address.
     */
    function setCollectingToken(address _address) public onlyOwner {
        require(_address != 0x0);
        require(_address != supplyTokenAddress);
        NewCollectingToken(collectingTokenAddress, _address);
        collectingTokenAddress = _address;
        collectingToken = BurnableERC20(_address);
    }

    /**
     * @dev Returns supply token balance.
     */
    function totalSupply() public view returns (uint) {
        return supplyToken.balanceOf(this);
    }

    /**
     * @dev buySupplyToken; the place where exchanges are done.
     * @param _value The number of tokens.
     */
    function buySupplyToken(uint _value) public {
        require(_value <= collectingToken.allowance(msg.sender,this));
        ExchangeRequest(msg.sender, _value, supplyTokenAddress);
        uint256 supplyToSend = _value.mul(RATE_MULTIPLIER) / rate;

        if (supplyToSend > supplyToken.balanceOf(this)) {
            uint256 leesSupplyToken = supplyToken.balanceOf(this);
            _value = leesSupplyToken.mul(rate) / RATE_MULTIPLIER;
        }
        collectingToken.transferFrom(msg.sender, this, _value);
        collectingToken.burn(_value);
        supplyToken.transfer(msg.sender, supplyToSend);
        SupplySent(msg.sender, supplyToSend, supplyTokenAddress);
    }
}