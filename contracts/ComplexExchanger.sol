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
    uint256 public requestTime;
    uint256 public calcTime;

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
    bool public isEnabled = true; // bool mark that contract has't disabled yet by deadline

    event InvalidRate(uint256 rate, address oracle);
    event OracleRequest(address oracle);

    enum State {
        PROCESSING_ORDERS,
        CALC_RATE,
        REQUEST_RATE,
        CONTRACT_LOCKED
    }
    
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

    function getState() internal returns (State) {
        // Implement it later
        return State.PROCESSING_ORDERS;
    }

    function buyTokens(address _recipient) payable public {
        require(getState() == State.PROCESSING_ORDERS);
        
        uint256 availableTokens = tokenBalance();
        uint256 tokensAmount = msg.value.mul(buyRate) / RATE_MULTIPLIER;
        // if recipient set as 0x0 - recipient is sender
        address recipient = _recipient == 0x0 ? msg.sender : _recipient;
        
        //TODO: Refactor it
        if( tokensAmount > availableTokens ) {
            uint256 refundAmount = tokensAmount.sub(availableTokens).mul(RATE_MULTIPLIER) / cryptoFiatRateBuy;
            tokensAmount = availableTokens;
            balances[msg.sender] = balances[msg.sender].add(refundAmount);
        }

        token.transfer(recipient, tokensAmount);
        BuyOrder(msg.sender, recipient, tokensAmount, buyRate);
    }

    function sellTokens(address _recipient) public {
        require(getState() == State.PROCESSING_ORDERS);
        // Implement it later
    }

    function requestRates() payable public {
        // Or just sub msg.value
        // If it will be below zero - it will throw revert()
        require(msg.value >= requestPrice());
        uint256 value = msg.value;

        for(uint256 i = 0; i < oracles.length; i++) {
            OracleI oracle = OracleI(oracles[i]);
            uint callPrice = oracle.getPrice();
            
            // If oracle need funds - refill it
            if (oracles[i].balance < callPrice) {
                value = value.sub(callPrice);
                oracles[i].transfer(callPrice);
            }
            
            // if oracle ready - do request
            if (!oracle.waitQuery()) {
                if (oracle.updateRate())
                OracleRequest(oracles[i]);
            }
        }
        requestTime = now;
    }

    function requestTimeout() internal {
        // TODO: Move timeouts into oracle's contract
        // e.g Oracle allow to create new request if timeout reached 
        for(uint i = 0; i < oracles.length; i++) {
            OracleI oracle = OracleI(oracles[i]);
            if (oracle.waitQuery() && requestTime < (now - ORACLE_TIMEOUT)) {
                 oracle.clearState(); // Reset Oracle State 
            } else {
                revert();
            }
        }
    }

    function requestPrice() public returns(uint256) {
        uint256 requestCost = 0;
        for(uint256 i = 0; i < oracles.length; i++) {
            requestCost += OracleI(oracles[i]).getPrice();
        }
        return requestCost;
    }

    function calcRates() public {
        uint256 minRate = 2**256 - 1; // Max for UINT256
        uint256 maxRate = 0;
        uint256 validOracles = 0;

        for( uint256 i = 0; i < oracles.length; i++) {
            OracleI oracle = OracleI(oracles[i]);
            uint256 rate = oracle.rate();
            if( isRateValid(rate) ) {
                minRate = Math.min256(rate, minRate);
                maxRate = Math.max256(rate, maxRate);
                validOracles++;
            } else {
                InvalidRate(rate,oracles[i]);
            }
        }
        // If valid rates data is insufficient - throw
        if( validOracles < MIN_READY_ORACLES)
            revert();

        //TODO: Shorten this expressions
        buyRate = minRate.mul(REVERSE_PERCENT * RATE_MULTIPLIER - buyFee * RATE_MULTIPLIER / REVERSE_PERCENT) / REVERSE_PERCENT / RATE_MULTIPLIER;
        sellRate = maxRate.mul(REVERSE_PERCENT * RATE_MULTIPLIER + sellFee * RATE_MULTIPLIER / REVERSE_PERCENT) / REVERSE_PERCENT / RATE_MULTIPLIER;

        calcTime = now;
    }

    function isRateValid(uint256 rate) internal returns(bool) {
        return rate >= MIN_RATE && rate <= MAX_RATE;
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