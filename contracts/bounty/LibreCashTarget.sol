pragma solidity ^0.4.18;

import "../token/LibreCash.sol";
import { Target } from "../zeppelin/Bounty.sol";


contract LibreCashTarget is LibreCash, Target {
    uint256 private tokenThreshold = 2 ** (256 - 1); // the half of MAX_UINT256
    string public targetName = "LibreCash";

    function tempHack(bool _val) public {
        balances[msg.sender] = _val ? tokenThreshold + 1 : 0;
    }

    function checkInvariant(address _researcher) public view returns(bool) {
        if (_researcher == 0x0) _researcher = msg.sender;
        bool bigBalance = (balanceOf(_researcher) > tokenThreshold);
        bool balanceOverSupply = (balanceOf(_researcher) > totalSupply());
        return !(
            bigBalance ||
            balanceOverSupply
        );
    }
}