pragma solidity ^0.4.10;

import "../zeppelin/ownership/Ownable.sol";

/**
 * @title Base contract for Libre oracles.
 *
 * @dev Base contract for Libre oracles. Not abstract.
 */
contract OwnOracle is Ownable {
    event NewOraclizeQuery();
    event NewPriceTicker(uint256 price);
    event BankSet(address bankAddress);
    event UpdaterAddressSet(address _updaterAddress);

    bytes32 public oracleName = "Base Oracle";
    bytes32 public oracleType = "Undefined";
    uint256 constant RATE_MULTIPLIER = 1000;
    uint256 public updateTime;
    uint256 public callbackTime;
    address public bankAddress;
    uint256 public rate;
    uint256 public requestPrice = 0;
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
     * @dev Clears queryId, updateTime and rate. Needs then response doesn't got properly
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
     * @dev Return price of LibreOracle request.
     */
    function getPrice() view public returns (uint) {
        return updaterAddress.balance < requestPrice ? requestPrice : 0;
    }

    /**
     * @dev oraclize getPrice.
     */
    function setPrice(uint256 _requestPriceWei) public onlyOwner returns (uint) {
        requestPrice = _requestPriceWei;
    }

    /**
     * @dev Requests updating rate from oraclize.
     */
    function updateRate() external onlyBank returns (bool) {
        NewOraclizeQuery();
        waitQuery = true;
        return true;
    }


    /**
    * @dev LibreOracle callback.
    * @param result The callback data.
    */
    function __callback(uint256 result) public {
        require(msg.sender == updaterAddress && waitQuery);
        rate = result * RATE_MULTIPLIER;
        updateTime = now;
        callbackTime = now;
        waitQuery = false;
        NewPriceTicker(result);
    }

    /**
    * @dev Method used for funding LibreOracle updater wallet   
    */    
    function () public payable {
        updaterAddress.transfer(msg.value);
    }

}