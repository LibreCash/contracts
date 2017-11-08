pragma solidity ^0.4.11;
// Ropsten 0x8327eDFdAcdA52fE812C8098D64886A819450d75
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/math/SafeMath.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/ownership/Ownable.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/token/PausableToken.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/token/MintableToken.sol";


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
    event Mint(address indexed burner, uint256 value);

    modifier onlyBank() {
        require(msg.sender == bankContract);
        _;
    }

    function LibreCoin() public {
        totalSupply = 0;
        owner = msg.sender;
        mint(msg.sender, 1000);
        
    }
    

    function getTokensAmount() public constant returns(uint256) {
        return totalSupply;
    }


    function setBankAddress(address _bankContractAddress) onlyBank public {
        require(_bankContractAddress != 0x0);
        bankContract = _bankContractAddress;
    }


  function mint(address _to, uint256 _amount) canMint onlyBank  returns (bool){
    totalSupply = totalSupply.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    Mint(_to, _amount);
    Transfer(0x0, _to, _amount);
    return true;
  }


    function burn(address burner, uint256 _value)  onlyBank {
        require(_value > 0);
        balances[burner] = balances[burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(burner, _value);
    }

}


