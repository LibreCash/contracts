pragma solidity ^0.4.10;

import "../zeppelin/token/StandardToken.sol";

/**
 * @title LibreCash token contract.
 *
 * @dev ERC20 token contract.
 */
contract LibreCash is StandardToken {
    string public version = "0.1.1";
    string public constant name = "LibreCash Token";
    string public constant symbol = "LCT";
    uint32 public constant decimals = 18;
    address public bankAddress;
    
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 value);
    event BankSet(address bankAddres);

    modifier onlyBank() {
        require(msg.sender == bankAddress);
        _;
    }

    /**
     * @dev Sets new bank address.
     * @param _bankAddress The bank address.
     * no onlyOwner for tests
     */
    function setBankAddress(address _bankAddress) /*onlyOwner*/ public {
        require(_bankAddress != 0x0);
        bankAddress = _bankAddress;
        BankSet(_bankAddress);
    }

    /**
     * @dev Minting function.
     * @param _to The address.
     * @param _amount The amount.
     */
    function mint(address _to, uint256 _amount) onlyBank public returns (bool) {
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        Mint(_to, _amount);
        Transfer(address(this), _to, _amount);
        return true;
    }

    /**
     * @dev Returns total coin supply.
     */
    function getTokensAmount() public view returns(uint256) {
        return totalSupply;
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
    function burn(address _burner, uint256 _value) onlyBank public {
        require(_value > 0);
        balances[_burner] = balances[_burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(_burner, _value);
    }

    /**
    * @dev Reject all ERC23 compatible tokens
    * @param from_ address The address that is transferring the tokens
    * @param value_ uint256 the amount of the specified token
    * @param data_ Bytes The data passed from the caller.
    */
    function tokenFallback(address from_, uint256 value_, bytes data_) external {
        revert();
    }
}