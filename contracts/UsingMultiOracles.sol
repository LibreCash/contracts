pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";
import "./PriceFeesLimits.sol";

interface oracleInterface {
    function updateRate() payable public returns (bytes32);
    function getName() constant public returns (bytes32);
    function setBank(address _bankAddress) public;
    function hasReceivedRate() public returns (bool);
}


/**
 * @title UsingMultiOracles.
 *
 * @dev Contract.
 */
contract UsingMultiOracles is PriceFeesLimits {
    using SafeMath for uint256;

    event InsufficientOracleData(string description, uint256 oracleCount);
    event OraclizeStatus(address indexed _address, bytes32 oraclesName, string description);
    event OraclesTouched(string description);
    event OracleAdded(address indexed _address, bytes32 name);
    event OracleEnabled(address indexed _address, bytes32 name);
    event OracleDisabled(address indexed _address, bytes32 name);
    event OracleDeleted(address indexed _address, bytes32 name);
    event OracleTouched(address indexed _address, bytes32 name);
    event OracleCallback(address indexed _address, bytes32 name, uint256 result);
    event TextLog(string data);
    // Извещения о критических ситуациях
    /*
а) Резкое падение обеспечение
б) Значительный рост волатильности
в) Значительные различия между оракулами
г) Несколько неудачных попыток достучаться до оракулов
д) Снижение числа доступных оракулов меньше чем до №
    */
    event ReservesAlert (string description, uint bankBalance, uint tokensSupply);
    event VolatilityAlert (string description);
    event OraculusDivergenceAlert (string description);
    event LowOraclesNumberAlert (string description);

    uint constant MAX_ORACLE_RATING = 10000;
    uint contant MIN_ORACLE_BALANCE = 200 finney;

    struct OracleData {
        bytes32 name;
        uint256 rating;
        bool enabled;
        //bool waiting;
        bytes32 queryId;
        uint256 updateTime; // time of callback
        uint256 cryptoFiatRate; // exchange rate
        uint listPointer; // чтобы знать по какому индексу удалять из массива oracleAddresses
    }

    mapping (address=>OracleData) oracles;
    address[] oracleAddresses;


    uint256 public numWaitingOracles;
    uint256 public numEnabledOracles;
    // maybe we should add weightWaitingOracles - sum of rating of waiting oracles


    /**
     * @dev Gets oracle count.
     */
    function getOracleCount() public view returns (uint) {
        return oracleAddresses.length;
    }

    function getWaitingOracleCount() public view returns (uint count) {
        count = 0;
        for (uint i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].queryId != 0) {
                count++;
            }
        }
    }

    function getEnabledOracleCount() public view returns (uint count) {
        count = 0;
        for (uint i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].enabled) {
                count++;
            }
        }
    }

    function isOracle(address _address) internal view returns (bool) {
        for (uint i = 0; i < oracleAddresses.length; i++) {
            if (oracleAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Adds an oracle.
     * @param _address The oracle address.
     */
    function addOracle(address _address) public onlyOwner {
        require(!isOracle(_address));
        require(_address != 0x0);
        oracleInterface currentOracleInterface = oracleInterface(_address);
        // TODO: возможно нам не нужно обращаться к оракулу лишний раз
        // только чтобы имя получить?
        // возможно, стоит добавить параметр name в функцию, тем самым упростив всё
        bytes32 oracleName = currentOracleInterface.getName();
        OracleData memory thisOracle = OracleData({name: oracleName, rating: MAX_ORACLE_RATING.div(2), 
                                                    enabled: true, queryId: 0, updateTime: 0, cryptoFiatRate: 0, listPointer: 0});
        oracles[_address] = thisOracle;
        // listPointer - индекс массива oracleAddresses с адресом оракула. Надо для удаления
        oracles[_address].listPointer = oracleAddresses.push(_address) - 1;
        currentOracleInterface.setBank(address(this));
        numEnabledOracles++;
        OracleAdded(_address, oracleName);
    }

    /**
     * @dev Disable oracle.
     * @param _address The oracle address.
     */
    function disableOracle(address _address) public onlyOwner {
        require(isOracle(_address));
        require(oracles[_address].enabled);
        oracles[_address].enabled = false;
        OracleDisabled(_address, oracles[_address].name);
        if (numEnabledOracles!=0) {
            numEnabledOracles--;
        }
    }

    /**
     * @dev Enable oracle.
     * @param _address The oracle address.
     */
    function enableOracle(address _address) public onlyOwner {
        require(isOracle(_address));
        require(!oracles[_address].enabled);
        oracles[_address].enabled = true;
        OracleEnabled(_address, oracles[_address].name);
        numEnabledOracles++;
    }

    /**
     * @dev Delete oracle.
     * @param _address The oracle address.
     */
    function deleteOracle(address _address) public onlyOwner {
        require(isOracle(_address));
        OracleDeleted(_address, oracles[_address].name);
        // может быть не стоит удалять ждущие? обсудить - Дима
        if (oracles[_address].queryId != bytes32("")) {
            numWaitingOracles--;
        }
        if (oracles[_address].enabled) {
            numEnabledOracles--;
        }
        // так. из мэппинга оракулов по адресу получаем индекс в массиве оракулов с адресом оракула
        uint indexToDelete = oracles[_address].listPointer;
        // теперь получаем адрес последнего оракула из массива адресов
        address keyToMove = oracleAddresses[oracleAddresses.length - 1];
        // перезаписываем удаляемый оракул последним (в массиве адресов)
        oracleAddresses[indexToDelete] = keyToMove;
        // а в мэппинге удалим
        delete oracles[_address];
        // у бывшего последнего оракула из массива адресов теперь новый индекс в массиве
        oracles[keyToMove].listPointer = indexToDelete;
        // уменьшаем длину массива адресов, адрес в конце уже на месте удалённого стоит и нам не нужен
        oracleAddresses.length--;
    }

    /**
     * @dev Funds each oracle till its balance is 0.2 eth (TODO: make a var for 0.2 eth).
     */
    function fundOracles() public payable {
        for (uint i = 0; i < oracleAddresses.length; i++) {
            /* 200 finney = 0.2 ether */
            if (oracleAddresses[i].balance < MIN_ORACLE_BALANCE) {
               oracleAddresses[i].transfer(MIN_ORACLE_BALANCE - oracleAddresses[i].balance);
            }
        } // foreach oracles
    }
}