pragma solidity ^0.4.18;

import "../token/LibreCash.sol";
import { Target } from "../zeppelin/Bounty.sol";


contract LibreCashTarget is LibreCash, Target {
    function checkInvariant() public returns(bool) {
        return false;
    }
}