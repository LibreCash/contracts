pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";
import "./PriceFeesLimits.sol";

interface oracleInterface {
    function updateRate() payable public;
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

    struct OracleData {
        bytes32 name;
        uint256 rating;
        bool enabled;
        bool waiting;
        uint256 updateTime; // time of callback
        uint256 cryptoFiatRate; // exchange rate
        uint listPointer; // чтобы знать по какому индексу удалять из массива oracleAddresses
    }

    mapping (address=>OracleData) oracles;
    address[] oracleAddresses;



    // пока на все случаи возможные
    uint256 constant MIN_ENABLED_ORACLES = 0; //2;
    uint256 constant MIN_WAITING_ORACLES = 2; //количество оракулов, которое допустимо омтавлять в ожидании
    uint256 constant MIN_READY_ORACLES = 1; //2;
    uint256 constant MIN_ENABLED_NOT_WAITING_ORACLES = 1; //2;
    uint constant MAX_ORACLE_RATING = 10000;

    uint256 public numWaitingOracles;
    uint256 public numEnabledOracles;
    // maybe we should add weightWaitingOracles - sum of rating of waiting oracles
    uint256 timeUpdateRequested;




    /**
     * @dev Gets oracle count.
     */
    function getOracleCount() public view returns (uint) {
        return oracleAddresses.length;
    }

    function isNotOracle (address _address) returns (bool) {
        for (uint i = 0; i < oracleAddresses.length; i++) {
            require (oracles[oracleAddresses[i]] != _address);
        }
        return true;
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Adds an oracle.
     * @param _address The oracle address.
     */
    function addOracle(address _address) public onlyOwner {
        require(isNotOracle ( _address));
        require(_address != 0x0);
        oracleInterface currentOracleInterface = oracleInterface(_address);
        // TODO: возможно нам не нужно обращаться к оракулу лишний раз
        // только чтобы имя получить?
        // возможно, стоит добавить параметр name в функцию, тем самым упростив всё
        bytes32 oracleName = currentOracleInterface.getName();
        OracleData memory thisOracle = OracleData({name: oracleName, rating: MAX_ORACLE_RATING.div(2), 
                                                    enabled: true, waiting: false, updateTime: 0, cryptoFiatRate: 0, listPointer: 0});
        oracles[_address] = thisOracle;
        // listPointer - индекс массива oracleAddresses с адресом оракула. Надо для удаления
        oracles[_address].listPointer = oracleAddresses.push(_address) - 1;
        currentOracleInterface.setBank(address(this));
        numEnabledOracles++;
        OracleAdded(_address, oracleName);
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Disable oracle.
     * @param _address The oracle address.
     */
    function disableOracle(address _address) public onlyOwner {
        require(!isNotOracle( _address));
        oracles[_address].enabled = false;
        OracleDisabled(_address, oracles[_address].name);
        if (numEnabledOracles!=0) {
            numEnabledOracles--;
        }
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Enable oracle.
     * @param _address The oracle address.
     */
    function enableOracle(address _address) public onlyOwner {
        require(!isNotOracle( _address));
        oracles[_address].enabled = true;
        OracleEnabled(_address, oracles[_address].name);
        numEnabledOracles++;
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Delete oracle.
     * @param _address The oracle address.
     */
    function deleteOracle(address _address) public onlyOwner {
        require(!isNotOracle( _address));
        OracleDeleted(_address, oracles[_address].name);
        // может быть не стоит удалять ждущие? обсудить - Дима
        if (oracles[_address].waiting) {
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
     * @dev Gets oracle name.
     * @param _address The oracle address.
     */
    function getOracleName(address _address) public view returns(bytes32) {
        return oracles[_address].name;
    }
    
    /**
     * @dev Gets oracle rating.
     * @param _address The oracle address.
     */
    function getOracleRating(address _address) public view returns(uint256) {
        return oracles[_address].rating;
    }

    /**
     * @dev Gets oracle rate.
     * @param _address The oracle address.
     */
    function getOracleRate(address _address) public view returns(uint256) {
        return oracles[_address].cryptoFiatRate;
    }

    /**
     * @dev Funds each oracle till its balance is 0.2 eth (TODO: make a var for 0.2 eth).
     */
    function fundOracles() public payable {
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            /* 200 finney = 0.2 ether */
            if (oracleAddresses[i].balance < 200 finney) {
               oracleAddresses[i].transfer(200 finney - oracleAddresses[i].balance);
            }
        } // foreach oracles
    }

}