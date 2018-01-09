pragma solidity ^0.4.11;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/ownership/Ownable.sol";


contract ERC223BurnableInterface {
    uint public totalSupply;
    function balanceOf(address who) public constant returns (uint);
    function transfer(address to, uint value) public;
    function transfer(address to, uint value, bytes data) public;
    function burn(uint256 _value) public;
    event Transfer(address indexed from, address indexed to, uint value, bytes data);
    event Transfer(address indexed from, address indexed to, uint value);
    event Burn(address indexed burner, uint256 value);
}


/**
 * @title Token exchanger contract.
 *
 * @dev ERC223 token exchanger contract for an ICO.
 */
contract Exchanger is Ownable {
    using SafeMath for uint;

    address public supplyTokenAddress = 0x0;
    address public collectingTokenAddress = 0x0;
    ERC223BurnableInterface private supplyToken;
    ERC223BurnableInterface private collectingToken;
    uint constant RATE_MULTIPLIER = 10**9;
    uint public rate = 10**9; // 10**9 / RATE_MULTIPLIER = 1
    
    event NewCollectingToken(address oldTokenContract, address newTokenContract);
    event NewRate(uint oldRate, uint newRate);
    event Deposit(address tokenSender, uint tokenAmount, address tokenContract);
    event ExchangeRequest(address tokenSender, uint tokenAmount, bytes txData, address tokenContract);
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
        supplyToken = ERC223BurnableInterface(_address);
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
        collectingToken = ERC223BurnableInterface(_address);
    }

    function totalSupply() public view returns (uint) {
        return supplyToken.balanceOf(this);
    }
    
    // для теста, всегда должно быть равно нулю
    function totalCollecting() public view returns (uint) {
        return collectingToken.balanceOf(this);
    }
    
    /**
     * @dev Fallback; the place where exchanges are done.
     * @param _from The address of token sender.
     * @param _value The number of tokens.
     * @param _data The tx data; not used here.
     */
    function tokenFallback(address _from, uint _value, bytes _data) public tokens {
        if (msg.sender == supplyTokenAddress) {
            Deposit(_from, _value, msg.sender);
            return;
        }
        ExchangeRequest(_from, _value, _data, msg.sender);
        uint256 supplyToSend = _value.mul(rate) / RATE_MULTIPLIER;
        require(supplyToSend <= supplyToken.balanceOf(this));
        collectingToken.burn(_value);
        supplyToken.transfer(_from, supplyToSend);
        SupplySent(_from, supplyToSend, supplyTokenAddress);
    }
}