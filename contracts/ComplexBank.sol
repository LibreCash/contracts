pragma solidity ^0.4.18;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/math/Math.sol";
import "./zeppelin/lifecycle/Pausable.sol";
import "./interfaces/I_Oracle.sol";
import "./interfaces/I_Bank.sol";
import "./token/LibreCash.sol";

contract ComplexBank is Pausable, BankI {
    using SafeMath for uint256;
    address public tokenAddress;
    LibreCash token;

    event Buy(address sender, address recipient, uint256 tokenAmount, uint256 price);
    event Sell(address sender, address recipient, uint256 cryptoAmount, uint256 price);

    uint256 constant public MIN_READY_ORACLES = 2;
    uint256 constant public MIN_ORACLES_ENABLED = 2;
    uint256 constant public FEE_MULTIPLIER = 100;
    uint256 constant public RATE_MULTIPLIER = 1000; // doubling in oracleBase __callback as parseIntRound(..., 3) as 3

    uint256 public requestTime = 0; // the time of requestRates()
    uint256 public calcTime = 0; // the time of calcRates()
    uint256 public oracleTimeout = 10 minutes; // Timeout to wait oracle data
    uint256 public oracleActual = oracleTimeout + 5 minutes;
    // RATE_PERIOD should be greater than or equal to ORACLE_ACTUAL
    uint256 public ratePeriod = 15 minutes;
    bool public locked = false;
    uint256 public reserveTokens = 0; // how many tokens (mint - burn) this bank


    enum State {
        LOCKED,
        PROCESSING_ORDERS,
        WAIT_ORACLES,
        CALC_RATES,
        REQUEST_RATES
    }

    modifier state(State needState) {
        require(getState() == needState);
        _;
    }

    function ComplexBank(address _token, uint256 _buyFee, uint256 _sellFee, address[] _oracles) 
        public
    {
        tokenAddress = _token;
        token = LibreCash(tokenAddress);
        buyFee = _buyFee;
        sellFee = _sellFee;

        uint i = 0;
        for(;i < _oracles.length; i++)
            addOracle(_oracles[i]);

    }

    /**
     * @dev get contract state.
     */
    function getState() public view returns (State) {
        if (locked)
            return State.LOCKED;

        if (now - calcTime < ratePeriod)
            return State.PROCESSING_ORDERS;

        if (waitingOracles() != 0)
            return State.WAIT_ORACLES;
        
        if (readyOracles() >= MIN_READY_ORACLES)
            return State.CALC_RATES;

        return State.REQUEST_RATES;
    }

    // 01-emission start

    /**
     * @dev Creates buy order.
     * @param _recipient Recipient.
     */
    function buyTokens(address _recipient)
        payable
        public
        whenNotPaused
        state(State.PROCESSING_ORDERS)
    {
        uint256 tokensAmount = msg.value.mul(buyRate) / RATE_MULTIPLIER;
        require(tokensAmount != 0);

        // if recipient set as 0x0 - recipient is sender
        address recipient = _recipient == 0x0 ? msg.sender : _recipient;

        token.mint(recipient, tokensAmount);
        reserveTokens = reserveTokens.add(tokensAmount);
        Buy(msg.sender, recipient, tokensAmount, buyRate);
    }

    /**
     * @dev Creates sell order.
     * @param _recipient Recipient.
     * @param tokensCount Amount of tokens to sell.
     */
    function sellTokens(address _recipient, uint256 tokensCount) 
        public 
        whenNotPaused 
        state(State.PROCESSING_ORDERS)
    {
        require(tokensCount <= token.allowance(msg.sender, this));

        uint256 cryptoAmount = tokensCount.mul(RATE_MULTIPLIER) / sellRate;
        require(cryptoAmount != 0);

        if (cryptoAmount > this.balance) {
            uint256 extraTokens = (cryptoAmount - this.balance).mul(sellRate) / RATE_MULTIPLIER;
            cryptoAmount = this.balance;
            tokensCount = tokensCount.sub(extraTokens);
        }

        token.transferFrom(msg.sender, this, tokensCount);
        token.burn(tokensCount);
        reserveTokens = reserveTokens.sub(tokensCount);
        address recipient = _recipient == 0x0 ? msg.sender : _recipient;

        Sell(msg.sender, recipient, cryptoAmount, sellRate);
        recipient.transfer(cryptoAmount);
    }

    /**
     * @dev Fallback function.
     */
    function() external payable {
        buyTokens(msg.sender);
    }

    // 01-emission end

    /**
     * @dev Attaches token contract.
     * @param _tokenAddress The token address.
     */
    function attachToken(address _tokenAddress) public onlyOwner {
        require(_tokenAddress != 0x0);
        tokenAddress = _tokenAddress;
        token = LibreCash(tokenAddress);
    }

    // 03-oracles methods start
    event OracleAdded(address indexed _address, bytes32 name);
    event OracleEnabled(address indexed _address, bytes32 name);
    event OracleDisabled(address indexed _address, bytes32 name);
    event OracleDeleted(address indexed _address, bytes32 name);
    event OracleRequest(address indexed _address, bytes32 name);
    event OracleError(string description);

    struct OracleData {
        bytes32 name;
        bool enabled;
        address next;
    }

    mapping (address => OracleData) oracles;
    uint256 public countOracles;
    uint256 public numEnabledOracles;
    address public firstOracle = 0x0;

    uint256 public buyRate = 1000;
    uint256 public sellRate = 1000;
    uint256 public buyFee = 0;
    uint256 public sellFee = 0;
    uint256 constant MAX_FEE = 70 * FEE_MULTIPLIER; // 70%

    address public scheduler;

    /**
     * @dev Gets oracle data.
     * @param _address Oracle address.
     */
    function getOracleData(address _address) 
        public 
        view 
        returns (bytes32, bytes32, uint256, bool, bool, uint256, address)
                /* name, type, upd_time, enabled, waiting, rate, next */
    {
        OracleI currentOracle = OracleI(_address);
        OracleData memory oracle = oracles[_address];

        return(
            oracle.name,
            currentOracle.oracleType(),
            currentOracle.updateTime(),
            oracle.enabled,
            currentOracle.waitQuery(),
            currentOracle.rate(),
            oracle.next
        );
    }

    /**
     * @dev Returns ready (which have data to be used) oracles count.
     */
    function readyOracles() public view returns (uint256) {
        uint256 count = 0;
        for (address current = firstOracle; current != 0x0; current = oracles[current].next) {
            if (!oracles[current].enabled) 
                continue;
            OracleI currentOracle = OracleI(current);
            if ((currentOracle.rate() != 0) &&
                !currentOracle.waitQuery() &&
                (now - currentOracle.updateTime()) < oracleActual)
                count++;
        }
        return count;
    }

    /**
     * @dev Returns waiting oracles count.
     */
    function waitingOracles() public view returns (uint256) {
        uint256 count = 0;
        for (address current = firstOracle; current != 0x0; current = oracles[current].next) {
            if (!oracles[current].enabled) 
                continue;
            if (OracleI(current).waitQuery() && (now - requestTime) < oracleTimeout) {
                count++;
            }
        }

        return count;
    }

    /**
     * @dev Lets owner to set  Oracle timeout period.
     * @param _period Oracle data waiting timeout.
     */
    function setOracleTimeout(uint256 _period) public onlyOwner {
        oracleTimeout = _period;
    }

    /**
     * @dev Lets owner to set  Oracle actual period.
     * @param _period Oracle data actual timeout.
     */
    function setOracleActual(uint256 _period) public onlyOwner {
        require (_period > oracleTimeout);
        oracleActual = _period;
    }

    /**
     * @dev Lets owner to set  rate period.
     * @param _period rate period.
     */
    function setRatePeriod(uint256 _period) public onlyOwner {
        ratePeriod = _period;
    }

    /**
     * @dev Lets owner to set  locked contract.
     * @param lock Set locked value.
     */
    function setLock(bool lock) public onlyOwner {
        locked = lock;
    }

    /**
     * @dev Returns whether the oracle exists in the bank.
     * @param _oracle The oracle's address.
     */
    function oracleExists(address _oracle) internal view returns (bool) {
        return !(oracles[_oracle].name == bytes32(0));
    }

    /**
     * @dev Sets buyFee and sellFee.
     * @param _buyFee The buy fee.
     * @param _sellFee The sell fee.
     */
    function setFees(uint256 _buyFee, uint256 _sellFee) public onlyOwner {
        require(_buyFee <= MAX_FEE);
        require(_sellFee <= MAX_FEE);

        if (sellFee != _sellFee) {
            uint256 maximalOracleRate = sellRate.mul(RATE_MULTIPLIER).mul(FEE_MULTIPLIER) / (RATE_MULTIPLIER * FEE_MULTIPLIER + sellFee * RATE_MULTIPLIER / 100);
            sellFee = _sellFee;
            sellRate = maximalOracleRate.mul(RATE_MULTIPLIER * FEE_MULTIPLIER + sellFee * RATE_MULTIPLIER / 100) / (RATE_MULTIPLIER * FEE_MULTIPLIER);
        }
        if (buyFee != _buyFee) {
            uint256 minimalOracleRate = buyRate.mul(RATE_MULTIPLIER * FEE_MULTIPLIER) / (RATE_MULTIPLIER * FEE_MULTIPLIER - buyFee * RATE_MULTIPLIER / 100);
            buyFee = _buyFee;
            buyRate = minimalOracleRate.mul(RATE_MULTIPLIER * FEE_MULTIPLIER - buyFee * RATE_MULTIPLIER / 100) / (RATE_MULTIPLIER * FEE_MULTIPLIER);
        }
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
            enabled: true,
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

        countOracles++;
        numEnabledOracles++;
        OracleAdded(_address, oracleName);
    }

    /**
     * @dev Disables an oracle.
     * @param _address The oracle address.
     */
    function disableOracle(address _address) public onlyOwner {
        require((oracleExists(_address)) && (oracles[_address].enabled));
        oracles[_address].enabled = false;
        numEnabledOracles--;
        OracleDisabled(_address, oracles[_address].name);
    }

    /**
     * @dev Enables an oracle.
     * @param _address The oracle address.
     */
    function enableOracle(address _address) public onlyOwner {
        require((oracleExists(_address)) && (!oracles[_address].enabled));
        oracles[_address].enabled = true;
        numEnabledOracles++;
        OracleEnabled(_address, oracles[_address].name);
    }

    /**
     * @dev Deletes an oracle.
     * @param _address The oracle address.
     */
    function deleteOracle(address _address) public onlyOwner {
        require(oracleExists(_address));
        OracleDeleted(_address, oracles[_address].name);
        if (firstOracle == _address) {
            firstOracle = oracles[_address].next;
        } else {
            address prev = firstOracle;
            for (; oracles[prev].next != _address; prev = oracles[prev].next) { }
            oracles[prev].next = oracles[_address].next;
        }
        
        countOracles--;
        if (oracles[_address].enabled)
            numEnabledOracles--;
        delete oracles[_address];
    }

    /**
     * @dev Sends money to oracles and start requestRates.
     * @param fund Desired balance of every oracle.
     */
    function schedulerUpdateRate(uint256 fund) public {
        require(msg.sender == scheduler);
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (oracles[cur].enabled)
                cur.transfer((fund == 0) ? (OracleI(cur).getPrice()) : (fund));
        }
        requestRates();
    }

    /**
     * @dev Set scheduler
     * @param _scheduler new scheduler address
     */
    function setScheduler(address _scheduler) public onlyOwner {
        require(_scheduler != 0x0);
        scheduler = _scheduler;
    }
    
    /**
     * @dev Get need money for oracles.
     */
    function requestPrice() public view returns (uint256) {
        uint256 requestCost = 0;
        for (address curr = firstOracle; curr != 0x0; curr = oracles[curr].next) {
            OracleI oracle = OracleI(curr);
            if (oracles[curr].enabled) {
                uint callPrice = oracle.getPrice();
                if (curr.balance < callPrice) {
                    requestCost += callPrice - curr.balance;
                }
            }   
        }
        return requestCost;
    }

    /**
     * @dev Gets bank reserve.
     */
    function getReservePercent() public view returns (uint256) {
        uint256 reserve = 0;
        uint256 curBalance = this.balance;
        if ((curBalance != 0) && (sellRate != 0)) {
            uint256 needCrypto = (reserveTokens * RATE_MULTIPLIER) / sellRate;
            reserve = (curBalance * FEE_MULTIPLIER * 100) / needCrypto;
        }
        return reserve;
    }

    /**
     * @dev Requests every enabled oracle to get the actual rate.
     */
    function requestRates() payable public state(State.REQUEST_RATES) {
        require(numEnabledOracles >= MIN_ORACLES_ENABLED);
        uint256 sendValue = msg.value;

        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (oracles[cur].enabled) {
                OracleI oracle = OracleI(cur);
                uint callPrice = oracle.getPrice();
                if (cur.balance < callPrice) {
                    sendValue = sendValue.sub(callPrice);
                    cur.transfer(callPrice);
                }
                if (oracle.updateRate())
                    OracleRequest(cur, oracles[cur].name);
            }
        } // foreach oracles
        requestTime = now;
        
        if (sendValue > 0)
            msg.sender.transfer(sendValue);
    }

     // 03-oracles methods end


    // 04-spread calc start 
    /**
     * @dev Processes data from ready oracles to get rates.
     */
    function calcRates() public state(State.CALC_RATES) {
        uint256 minimalRate = 2**256 - 1; // Max for UINT256
        uint256 maximalRate = 0;

        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            OracleData memory currentOracleData = oracles[cur];
            OracleI currentOracle = OracleI(cur);
            uint256 _rate = currentOracle.rate();
            if ((currentOracleData.enabled) && (!currentOracle.waitQuery()) && (_rate != 0)) {
                minimalRate = Math.min256(_rate, minimalRate);
                maximalRate = Math.max256(_rate, maximalRate);
            }
        } // foreach oracles
        buyRate = minimalRate.mul(FEE_MULTIPLIER * RATE_MULTIPLIER - buyFee * RATE_MULTIPLIER / 100) / FEE_MULTIPLIER / RATE_MULTIPLIER;
        sellRate = maximalRate.mul(FEE_MULTIPLIER * RATE_MULTIPLIER + sellFee * RATE_MULTIPLIER / 100) / FEE_MULTIPLIER / RATE_MULTIPLIER;
        calcTime = now;
    }
    // 04-spread calc end

    // system methods start

    /**
     * @dev set new owner.
     * @param newOwner The new owner for token.
     */
    function transferTokenOwner(address newOwner) public onlyOwner {
        token.transferOwnership(newOwner);
    }

    /**
     * @dev Claims token ownership.
     */
    function claimOwnership() public onlyOwner {
        token.claimOwnership();
    }

    // TODO: Delete after tests. Used to withdraw balance in test network
    /**
     * @dev Withdraws all the balance to owner.
     */
    function withdrawBalance() public onlyOwner {
        owner.transfer(this.balance);
    }
}