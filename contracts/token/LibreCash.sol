pragma solidity ^0.4.23;

import 'openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol';
import 'openzeppelin-solidity/contracts/ownership/Claimable.sol';



/**
 * @title LibreCash token contract.
 *
 * @dev ERC20 token contract.
 */
contract LibreCash is MintableToken, BurnableToken, Claimable {
    string public constant name = "LibreCash";
    string public constant symbol = "Libre";
    uint32 public constant decimals = 18;
    uint256 public cap = 100000 ether;

    function setCap(uint256 _cap) public onlyOwner {
        require(_cap > 0);
        cap = _cap;
    }

    /**
    * @dev Function to mint tokens
    * @param _to The address that will receive the minted tokens.
    * @param _amount The amount of tokens to mint.
    * @return A boolean that indicates if the operation was successful.
    */
    function mint(
        address _to,
        uint256 _amount
    )
        onlyOwner
        canMint
        public
        returns (bool)
    {
        require(totalSupply_.add(_amount) <= cap);

        return super.mint(_to, _amount);
    }

}
