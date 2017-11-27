pragma solidity ^0.4.10;

import "../../zeppelin/ownership/Ownable.sol";
import "../../interfaces/I_Oracle.sol";

/**
 * @title Base contract for mocked oracles for testing in private nodes.
 *
 * @dev Base contract for oracles. Not abstract.
 */
contract OracleMockBase is Ownable {

    bytes32 public oracleName = "Mocked Base Oracle";
    bytes16 public oracleType = "Mocked Undefined";
    uint public rate;
    event NewPriceTicker(uint price);
    event Log(string description);

    uint256 public updateTime;
    address public bankAddress;
    bytes32 queryId = 0x0;
    bool public waitQuery = false;
    
    modifier onlyBank() {
        require(msg.sender == bankAddress);
        _;
    }

    /**
     * @dev Constructor.
     */
    function OracleBase(uint256 defaultMockRate) public {
        rate = defaultMockRate;
    }

    /**
     * @dev Sets bank address.
     * @param _bankAddress Description.
     */
    function setBank(address _bankAddress) public onlyOwner {
        bankAddress = _bankAddress;
    }

    /**
     * @dev oraclize getPrice.
     */
    function getPrice() view public returns (uint) {
        return 0;
    }

    /**
     * @dev Sends query to oraclize.
     */
    function updateRate() external onlyBank returns (bool) {
        updateTime = now;
        NewPriceTicker(rate);
        return true;
    }
    
    function setRate(uint newRate) external {
        rate = newRate;
    }

    function clearState() public onlyBank {
        waitQuery = false;
    }
}