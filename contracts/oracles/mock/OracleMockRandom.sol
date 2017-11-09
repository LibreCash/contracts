pragma solidity ^0.4.10;
import "./OracleMockBase.sol";

contract OracleMockRandom is OracleMockBase {
    function OracleMockRandom() {
        uint first_random_number = uint(block.blockhash(block.number-1))%10 + 1;
        uint second_random_number = uint(block.blockhash(block.number-2))%10 + 1;
        rate = first_random_number*second_random_number;
    }
}