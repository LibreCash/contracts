pragma solidity ^0.4.18;

import "../zeppelin/ownership/Ownable.sol";

contract ProxyStore is Ownable {
    mapping(address=>uint256) public addressOf;

    event TargetAdded(address _contract, string _description);
    struct Target {
        address contractAddr;
        string description;
    }

    Target[] contracts;

    function getTarget() view internal returns(Target) {
        return contracts[addressOf[msg.sender]];
    }

    function getAddress() public view returns(address) {
        return getTarget().contractAddr;
    }

    function addTarget(address _contract, string _description) public onlyOwner {
        contracts.push(Target(_contract,_description));
        emit TargetAdded(_contract,_description);
    }

    function setTarget(uint index) public {
        require(contracts[index].contractAddr != 0x0);
        addressOf[msg.sender] = index;
    }

}