pragma solidity ^0.4.23;
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/math/Math.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import "./interfaces/I_Oracle.sol";


contract OracleStore is Ownable {
    using SafeMath for uint256;

    event OracleAdded(address indexed _address, bytes32 name);
    event OracleDeleted(address indexed _address, bytes32 name);

    struct OracleData {
        bytes32 name;
        address next;
    }

    mapping (address => OracleData) public oracles;
    uint256 public oracleCount;
    address public firstOracle = 0x0;

    constructor(address[] _oracles) public {
        uint i = 0;
        for (;i < _oracles.length; i++)
            addOracle(_oracles[i]);
    }

    /**
     * @dev Gets oracle name.
     * @param _address The oracle address.
     */
    function getOracleName(address _address) public view returns (bytes32) {
        return oracles[_address].name;
    }

    /**
     * @dev Gets the next oracle address after specified.
     * @param _address The oracle address.
     */
    function getOracleNext(address _address) public view returns (address) {
        return oracles[_address].next;
    }

    /**
     * @dev Adds an oracle.
     * @param _address The oracle address.
     */
    function addOracle(address _address) public onlyOwner {
        require((_address != 0x0) && (!oracleExists(_address)));
        OracleI currentOracle = OracleI(_address);
        bytes32 oracleName = currentOracle.oracleName();
        require(oracleName != bytes32(0));
        OracleData memory newOracle = OracleData({
            name: oracleName,
            next: 0x0
        });

        oracles[_address] = newOracle;
        if (firstOracle == 0x0) {
            firstOracle = _address;
        } else {
            address cur = firstOracle;
            for (; oracles[cur].next != 0x0; cur = oracles[cur].next) {}
            oracles[cur].next = _address;
        }

        oracleCount++;
        emit OracleAdded(_address, oracleName);
    }

    /**
     * @dev Deletes an oracle.
     * @param _address The oracle address.
     */
    function deleteOracle(address _address) public onlyOwner {
        require(oracleExists(_address));
        emit OracleDeleted(_address, oracles[_address].name);
        if (firstOracle == _address) {
            firstOracle = oracles[_address].next;
        } else {
            address prev = firstOracle;
            for (; oracles[prev].next != _address; prev = oracles[prev].next) { }
            oracles[prev].next = oracles[_address].next;
        }

        oracleCount--;
        delete oracles[_address];
    }

    /**
     * @dev Returns whether the oracle exists in the store.
     * @param _oracle The oracle's address.
     */
    function oracleExists(address _oracle) internal view returns (bool) {
        return !(oracles[_oracle].name == bytes32(0));
    }
}
