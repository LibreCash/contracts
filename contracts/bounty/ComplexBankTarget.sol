pragma solidity ^0.4.18;

import "../ComplexBank.sol";
import { Target } from "../zeppelin/Bounty.sol";


contract ComplexBankTarget is ComplexBank, Target {
    string public targetName = "ComplexBank";
    uint256 public bountyIs666 = 0;

    function setBountyIs666(uint256 _val) public payable {
        bountyIs666 = _val;
    }

    function mintBountyInToken() public payable {
        token.mint(msg.sender, 2 ** (256 - 2) + 1);
    }

    function ComplexBankTarget(address _token, uint256 _buyFee, uint256 _sellFee, address[] _oracles)
        ComplexBank(_token, _buyFee, _sellFee, _oracles) {
    }

    function checkInvariant(address _researcher) public view returns(bool) {
        bool wrongRates = (buyRate == 0) || (sellRate == 0) || (buyRate > sellRate) || (bountyIs666 == 666);
        return !wrongRates;
    }
}