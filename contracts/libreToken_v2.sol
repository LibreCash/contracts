pragma solidity ^0.4.10;

import "./zeppelin/token/PausableToken.sol";
import "./zeppelin/token/MintableToken.sol";


// ERC20 Coin contract
contract libreCoin is MintableToken,PausableToken {
    string public version = "0.1.1";
    string public constant name = "LibreCash Token";
    string public constant symbol = "LCT";
    uint32 public constant decimals = 18;
    address public bankContract;

    modifier onlyBank() {
        require(msg.sender == bankContract);
        _;
    }

    function setBankAddress(address bankContractAddress) onlyOwner {
        require(bankContractAddress != 0x0);
        bankContract = bankContractAddress;
    }

    // Override default minting function
    function mint (address _to, uint256 _value) onlyBank {
        super.mint(_to,_value);
    }

    function getTokensAmount() public returns(uint256) {
        return totalSupply;
    }
}


