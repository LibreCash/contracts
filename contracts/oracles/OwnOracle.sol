pragma solidity ^0.4.10;

import "../zeppelin/ownership/Ownable.sol";
import "../library/Helpers.sol";
import "../interfaces/I_Oracle.sol";



/**
 * @title Base contract for oracles.
 *
 * @dev Base contract for oracles. Not abstract.
 */
contract OwnOracle is Ownable, OracleI {
    event NewOraclizeQuery(string description);
    event NewPriceTicker(uint256 price);
    event BankSet(address bankAddress);
    event UpdaterAddressSet(address _updaterAddress);

    bytes32 public oracleName = "Base Oracle";
    bytes16 public oracleType = "Undefined";
    uint256 public updateTime;
    address public bankAddress;
    uint256 public rate;
    bool public waitQuery = false;
    address public updaterAddress;

    modifier onlyBank() {
        require(msg.sender == bankAddress);
        _;
    }

    /**
     * @dev Constructor.
     */
    function OwnOracle(address _bankAddress) {
        bankAddress = _bankAddress;
        BankSet(_bankAddress);
    }

    /**
     * Clears queryId, updateTime and rate.
     */
    function clearState() public onlyBank {
        waitQuery = false;
        rate = 0;
        updateTime = 0;
    }

    /**
     * @dev Sets bank address.
     * @param _bankAddress Address of the bank contract.
     */
    function setBank(address _bankAddress) public onlyOwner {
        bankAddress = _bankAddress;
        BankSet(_bankAddress);
    }

    /**
     * @dev Sets updateAddress address.
     * @param _address Address of the updateAddress.
     */
    function setUpdaterAddress(address _address) public onlyOwner {
        updaterAddress = _address;
        UpdaterAddressSet(updaterAddress);
    }

    /**
     * @dev oraclize getPrice.
     */
    function getPrice() view public returns (uint) {
        return 0;
    }

    /**
     * @dev Requests updating rate from oraclize.
     */
    function updateRate() external onlyBank returns (bool) {
        NewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
        waitQuery = true;
        return true;
    }


    /**
    * @dev Oracle default callback.
    * @param result The callback data.
    */
    function __callback(uint256 result) public {
        require(msg.sender == updaterAddress);
        rate = result;
        NewPriceTicker(result);
        updateTime = now;
        waitQuery = false;
    }

    /**
    * @dev Method used for oracle funding   
    */    
    function () public payable {}

}