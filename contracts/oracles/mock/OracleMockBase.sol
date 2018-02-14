pragma solidity ^0.4.18;

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
    uint256 public rate = 0;
    uint256 public mockRate;
    event PriceTicker(uint price);

    uint256 public updateTime;
    uint256 public callbackTime;
    address public bankAddress;
    bool public waitQuery = false;
    uint256 constant MOCK_REQUEST_PRICE = 10000000000;
    uint256 public price = 0;
    
    
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
    function getPrice() public view returns (uint) {
        return price;
    }

    /**
     * @dev Sends query to oraclize.
     */
    function updateRate() external onlyBank returns (bool) {
        updateTime = now;
        callbackTime = now;
        rate = mockRate;

        if(price == 0) 
            price = MOCK_REQUEST_PRICE;

        PriceTicker(rate);
        return true;
    }

    function setWaitQuery(bool waiting) external {
        waitQuery = waiting;
    }
    
    function setRate(uint newRate) external {
        rate = newRate;
    }

    /**
    * @dev Method used for oracle funding   
    */    
    function () public payable {}
}