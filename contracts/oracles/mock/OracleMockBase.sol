pragma solidity ^0.4.10;

import "../../zeppelin/ownership/Ownable.sol";
import "../OracleBase.sol";

/**
 * @title Base contract for mocked oracles for testing in private nodes.
 *
 * @dev Base contract for oracles. Not abstract.
 */
contract OracleMockBase is OracleBase {
    bytes32 public oracleName = "Mocked Base Oracle";
    bytes16 public oracleType = "Mocked Undefined";
    uint rate = 100;
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
    function setBank(address _bankAddress) public {
        bankAddress = _bankAddress;
        bank = BankI(_bankAddress);
    }

    /**
     * @dev Gets bank address.
     */
    function getBank() public view returns (address) {
        return bankAddress;
    }

    /**
     * @dev Sends query to oraclize.
     */
    function updateRate() external returns (bytes32) {
        // для тестов отдельно оракула закомментировать след. строку
        require (msg.sender == bankAddress);
        // для тестов отдельно оракула закомментировать след. строку
        require (now > lastResultTimestamp + MIN_UPDATE_TIME);
        lastResultTimestamp = now;
        bank.oraclesCallback(rate, now);
    }

    
    function setRate(uint newRate) external {
        rate = newRate;
    }

    /**
    * @dev default callback with the proof set.
    */
   function __callback(bytes32 myid, string result, bytes proof) public {
        // Do nothing
    }

    /**
    * @dev Oraclize default callback without the proof set.
    */
   function __callback(bytes32 myid, string result) public {
       // Do nothing
    }


    /**
     * @dev Returns the oracle name.
     */
    function getName() constant public returns (bytes32) {
        return oracleName;
    }

    /**
     * @dev Returns the oracle type.
     */
    function getType() constant public returns (bytes16) {
        return oracleType;
    }

    /**
     * @dev Shall receive ETH for oraclize queries.
     */
    function () payable external { }
}