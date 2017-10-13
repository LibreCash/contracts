pragma solidity ^0.4.10;

import "./zeppelin/token/PausableToken.sol";
import "./zeppelin/token/MintableToken.sol";


// ERC20 Coin contract
contract libreCoin is MintableToken,PausableToken {
    string public version = "0.1.1";
    bytes32 public constant name = "LibreCash Token";
    string public constant symbol = "LCT";
    uint32 public constant decimals = 18;
    address public bankContract;

    event Burn(address indexed burner, uint256 value);

    modifier onlyBank() {
        require(msg.sender == bankContract);
        _;
    }

    function setBankAddress(address bankContractAddress) onlyOwner {
        require(bankContractAddress != 0x0);
        bankContract = bankContractAddress;
    }

    // Override default minting function
    function mint(address _to, uint256 _amount) onlyOwner canMint onlyBank returns (bool) {
        super.mint(_to,_amount);
    }

    function getTokensAmount() public returns(uint256) {
        return totalSupply;
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
    function burn(address burner, uint256 _value) public {
        require(_value > 0);

        balances[burner] = balances[burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(burner, _value);
    }
}