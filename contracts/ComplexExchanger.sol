pragma solidity ^0.4.17;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/math/Math.sol";
import "./interfaces/I_Oracle.sol";
import "./interfaces/I_Exchanger.sol";
import "./token/LibreCash.sol";


contract ComplexExchanger is ExchangerI {
    using SafeMath for uint256;

    address public tokenAddress;
    LibreCash token;
    address[] public oracles;
    uint256 public deadline;
    address public withdrawWallet;

    uint256 public requestTime;
    uint256 public calcTime;

    uint256 public buyRate;
    uint256 public sellRate;
    uint256 public buyFee;
    uint256 public sellFee;

    uint256 constant ORACLE_ACTUAL = 10 minutes;
    uint256 constant ORACLE_TIMEOUT = 10 minutes;
    uint256 constant RATE_PERIOD = 10 minutes;
    uint256 constant MIN_READY_ORACLES = 2;
    uint256 constant REVERSE_PERCENT = 100;
    uint256 constant RATE_MULTIPLIER = 1000;
    uint256 constant MAX_RATE = 5000 * RATE_MULTIPLIER;
    uint256 constant MIN_RATE = 100 * RATE_MULTIPLIER;
    
    event InvalidRate(uint256 rate, address oracle);
    event OracleRequest(address oracle);
    event Buy(address sender, address recipient, uint256 tokenAmount, uint256 price);
    event Sell(address sender, address recipient, uint256 cryptoAmount, uint256 price);
    event ReserveRefill(uint256 amount);
    event ReserveWithdraw(uint256 amount);

    enum State {
        PROCESSING_ORDERS,
        CALC_RATES,
        REQUEST_RATES,
        LOCKED,
        WAIT_ORACLES
    }
    
    function ComplexExchanger(
        address _token,
        uint256 _buyFee,
        uint256 _sellFee,
        address[] _oracles,
        uint256 _deadline, 
        address _withdrawWallet
    ) public
    {
        tokenAddress = _token;
        token = LibreCash(tokenAddress);
        oracles = _oracles;
        buyFee = _buyFee;
        sellFee = _sellFee;
        deadline = _deadline;
        withdrawWallet = _withdrawWallet;
    }

    /**
     * @dev Returns the contract state.
     */
    function getState() public view returns (State) {
        if (now >= deadline)
            return State.LOCKED;

        if (now - calcTime < RATE_PERIOD)
            return State.PROCESSING_ORDERS;

        if (waitingOracles() != 0 ) 
            return State.WAIT_ORACLES;
        
        if (readyOracles() >= MIN_READY_ORACLES)
            return State.CALC_RATES;

        return State.REQUEST_RATES;
    }

    /**
     * @dev Allows user to buy tokens by ether.
     * @param _recipient The recipient of tokens.
     */
    function buyTokens(address _recipient) public payable {
        require(getState() == State.PROCESSING_ORDERS);
        require(tokenBalance() > 0);
        
        uint256 availableTokens = tokenBalance();
        uint256 tokensAmount = msg.value.mul(buyRate) / RATE_MULTIPLIER;
        uint256 refundAmount = 0;
        // if recipient set as 0x0 - recipient is sender
        address recipient = _recipient == 0x0 ? msg.sender : _recipient;

        if (tokensAmount > availableTokens) {
            refundAmount = tokensAmount.sub(availableTokens).mul(RATE_MULTIPLIER) / buyRate;
            tokensAmount = availableTokens;
        }

        token.transfer(recipient, tokensAmount);
        Buy(msg.sender, recipient, tokensAmount, buyRate);
        if (refundAmount > 0)
            recipient.transfer(refundAmount);
    }

    /**
     * @dev Allows user to sell tokens and get ether.
     * @param _recipient The recipient of ether.
     * @param tokensCount The count of tokens to sell.
     */
    function sellTokens(address _recipient, uint256 tokensCount) public {
        require(getState() == State.PROCESSING_ORDERS);
        require(tokensCount <= token.allowance(msg.sender, this));
        
        token.transferFrom(msg.sender, this, tokensCount);

        address recipient = _recipient == 0x0 ? msg.sender : _recipient;
        uint256 cryptoAmount = tokensCount.mul(RATE_MULTIPLIER) / sellRate;

        if (cryptoAmount > this.balance) {
            uint256 extraTokens = (cryptoAmount - this.balance).mul(sellRate) / RATE_MULTIPLIER;
            cryptoAmount = this.balance;
            token.transfer(msg.sender, extraTokens);
        }

        Sell(msg.sender, recipient, cryptoAmount, sellRate);
        recipient.transfer(cryptoAmount);
    }

    /**
     * @dev Requests oracles rates updating; funds oracles if needed.
     */
    function requestRates() public payable {
        require(getState() == State.REQUEST_RATES);
        // Or just sub msg.value
        // If it will be below zero - it will throw revert()
        // require(msg.value >= requestPrice());
        uint256 value = msg.value;

        for (uint256 i = 0; i < oracles.length; i++) {
            OracleI oracle = OracleI(oracles[i]);
            uint callPrice = oracle.getPrice();
            
            // If oracle needs funds - refill it
            if (oracles[i].balance < callPrice) {
                value = value.sub(callPrice);
                oracles[i].transfer(callPrice);
            }
            
            if (oracle.updateRate())
                OracleRequest(oracles[i]);
        }
        requestTime = now;
    }

    /**
     * @dev Returns cost of requestRates function.
     */
    function requestPrice() public view returns(uint256) {
        uint256 requestCost = 0;
        for (uint256 i = 0; i < oracles.length; i++) {
            if (!OracleI(oracles[i]).waitQuery())
                requestCost += OracleI(oracles[i]).getPrice();
        }
        return requestCost;
    }

    /**
     * @dev Calculates buy and sell rates after oracles have received it.
     */
    function calcRates() public {
        require(getState() == State.CALC_RATES);
        requestTimeout();

        uint256 minRate = 2**256 - 1; // Max for UINT256
        uint256 maxRate = 0;
        uint256 validOracles = 0;

        for (uint256 i = 0; i < oracles.length; i++) {
            OracleI oracle = OracleI(oracles[i]);
            uint256 rate = oracle.rate();
            if (oracle.waitQuery()) {
                continue;
            }
            if (isRateValid(rate)) {
                minRate = Math.min256(rate, minRate);
                maxRate = Math.max256(rate, maxRate);
                validOracles++;
            } else {
                InvalidRate(rate, oracles[i]);
            }
        }
        // If valid rates data is insufficient - throw
        if (validOracles < MIN_READY_ORACLES)
            revert();

        //TODO: Shorten this expressions
        buyRate = minRate.mul(REVERSE_PERCENT * RATE_MULTIPLIER - buyFee * RATE_MULTIPLIER / REVERSE_PERCENT) / REVERSE_PERCENT / RATE_MULTIPLIER;
        sellRate = maxRate.mul(REVERSE_PERCENT * RATE_MULTIPLIER + sellFee * RATE_MULTIPLIER / REVERSE_PERCENT) / REVERSE_PERCENT / RATE_MULTIPLIER;

        calcTime = now;
    }

    /**
     * @dev Returns contract oracles' count.
     */
    function oracleCount() public view returns(uint256) {
        return oracles.length;
    }

    /**
     * @dev Returns token balance of the sender.
     */
    function tokenBalance() public view returns(uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @dev Returns data for an oracle by its id in the array.
     */
    function getOracleData(uint number) 
        public 
        view 
        returns (bytes32, bytes32, bool, uint256, uint256, uint256)
                /* name, type, waitQuery, updTime, clbTime, rate */
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

    /**
     * @dev Returns ready (which have data to be used) oracles count.
     */
    function readyOracles() public view returns (uint256) {
        // TODO: Refactor it to use in processing waintin oracles 
        uint256 count = 0;
        for (uint256 i = 0; i < oracles.length; i++) {
            OracleI oracle = OracleI(oracles[i]);
            if ((oracle.rate() != 0) && 
                !oracle.waitQuery() &&
                (now - oracle.callbackTime()) < ORACLE_ACTUAL)
                count++;
        }

        return count;
    }

    /**
     * @dev Returns wait query oracle count.
     */
    function waitingOracles() public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < oracles.length; i++) {
            if (OracleI(oracles[i]).waitQuery() && (now - requestTime) < ORACLE_TIMEOUT) {
                count++;
            }
        }

        return count;
    }

    /**
     * @dev Withdraws balance only to special hardcoded wallet ONLY WHEN contract is locked.
     */
    function withdrawReserve() public {
        require(getState() == State.LOCKED && msg.sender == withdrawWallet);
        ReserveWithdraw(this.balance);
        withdrawWallet.transfer(this.balance);
    }

    /**
     * @dev Allows to deposit eth to the contract without creating orders.
     */
    function refillBalance() public payable {
        ReserveRefill(msg.value);
    }

    /**
     * @dev Returns if given rate is within limits; internal.
     * @param rate Rate.
     */
    function isRateValid(uint256 rate) internal pure returns(bool) {
        return rate >= MIN_RATE && rate <= MAX_RATE;
    }
}