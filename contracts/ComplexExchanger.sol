pragma solidity ^0.4.17;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/math/Math.sol";
import "./interfaces/I_Oracle.sol";
import "./interfaces/I_Exchanger.sol";
import "./token/LibreCash.sol";

contract ComplexExchanger {
    using SafeMath for uint256;

    LibreCash token;
    address[] public oracles;
    uint256 public deadline;
    address public withdrawWallet;

    uint256 public totalHolded;
    uint256 public buyRate;
    uint256 public sellRate;
    uint256 public buyFee;
    uint256 public sellFee;

    mapping(address => uint256) balances;

    uint256 constant ORACLE_TIMEOUT = 10 minutes;
    uint256 constant RATE_PERIOD = 10 minutes;
    uint256 constant MIN_READY_ORACLES = 2;
    uint256 constant REVERSE_PERCENT = 100;
    uint256 constant RATE_MULTIPLIER = 1000;
    uint256 constant MAX_RATE = 5000 * RATE_MULTIPLIER;
    uint256 constant MIN_RATE = 100 * RATE_MULTIPLIER;

    
    function ComplexExchanger(
        address _token,
        uint256 _buyFee,
        uint256 _sellFee,
        uint256 _deadline, 
        address[] _oracles,
        address _withdrawWallet
    )
    {
        address tokenAddress = _token;
        token = LibreCash(tokenAddress);
        oracles = _oracles;

        buyFee = _buyFee;
        sellFee = _sellFee;
        deadline = _deadline;
        withdrawWallet = _withdrawWallet;
    }

    function balanceOf(address _owner) view public returns(uint256) {
        return balances[_owner];
    }

    function oraclesCount() public view returns(uint256) {
        return oracles.length;
    }

    function tokenBalance() public view returns(uint256) {
        return token.balanceOf(address(this));
    }

    function getOracleData(uint number) 
        public 
        view 
        returns (bytes32, bytes32, bool, uint256, uint256, uint256)
                /* name, type, waitQuery, updTime, clbTime, rate, */
    {
        OracleI curOracle = OracleI(oracles[number]);

        return( 
            curOracle.oracleName(),
            curOracle.oracleType(),
            curOracle.waitQuery(),
            curOracle.updateTime(),
            curOracle.callbackTime(),
            curOracle.rate()
        );
    }

    function claimBalance() public {
        require(balanceOf(msg.sender) > 0);
        msg.sender.transfer(balanceOf(msg.sender));
    }



}