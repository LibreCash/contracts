pragma solidity ^0.4.10;

import "./zeppelin/token/PausableToken.sol";
import "./zeppelin/token/MintableToken.sol";

/**
 * @title LibreCoin contract.
 *
 * @dev ERC20 Coin contract.
 */
contract LibreCoin is MintableToken, PausableToken {
    string public version = "0.1.1";
    string public constant name = "LibreCash Token";
    string public constant symbol = "LCT";
    uint32 public constant decimals = 18;
    address public bankContract;

    event Burn(address indexed burner, uint256 value);

    modifier onlyBank() {
        require(msg.sender == bankContract);
        _;
    }

//    function LibreCoin() public {
//    }

    /**
     * @dev Sets new bank address.
     * @param _bankContractAddress The bank address.
     */
    function setBankAddress(address _bankContractAddress) onlyOwner public /*private*/ {
        require(_bankContractAddress != 0x0);
        bankContract = _bankContractAddress;
    }

    // только для тестов
    function toString(address x) returns (string) {
        bytes memory b = new bytes(20);
        for (uint i = 0; i < 20; i++)
            b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
        return string(b);
    }
    function getBankAddress() constant public returns (string) {
        string memory returnValue = toString(bankContract);
        return returnValue;
    }
    // конец временного фрагмента для тестов

    /**
     * @dev Overrides default minting function.
     * @param _to The address.
     * @param _amount The amount.
     */
    function mint(address _to, uint256 _amount) canMint onlyBank public returns (bool) {
        super.mint(_to, _amount);
    }

    /**
     * @dev Returns total coin supply.
     */
    function getTokensAmount() public constant returns(uint256) {
        return totalSupply;
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
    function burn(address burner, uint256 _value) onlyBank public {
        require(_value > 0);
        balances[burner] = balances[burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(burner, _value);
    }
}