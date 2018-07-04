pragma solidity ^0.4.23;
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/math/Math.sol';
import "./OracleStore.sol";
import "./interfaces/I_OracleFeed.sol";
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';


contract OracleFeed is Ownable, OracleFeedI {
    using SafeMath for uint256;

    OracleStore public store;
    address public scheduler;

    uint256 public oracleActual = 15 minutes;
    uint256 public oracleTimeout = 10 minutes;
    // ratePeriod should be greater than or equal to oracleActual
    uint256 public ratePeriod = 15 minutes;
    uint256 constant public MIN_READY_ORACLES = 2;
    uint256 constant public MIN_ORACLES = 2;
    uint256 constant RATE_MULTIPLIER = 1000;
    uint256 constant MAX_RATE = 5000 * RATE_MULTIPLIER;
    uint256 constant MIN_RATE = 100 * RATE_MULTIPLIER;

    event OracleRequest(address indexed _address, bytes32 name);
    event OracleError(string description);

    uint256 public buyRate = 1000;
    uint256 public sellRate = 1000;
    uint256 public requestTime;
    uint256 public calcTime;

    enum State {
        LOCKED, // not used here; for compatibility
        PROCESSING_ORDERS,
        WAIT_ORACLES,
        CALC_RATES,
        REQUEST_RATES
    }

    modifier state(State needState) {
        require(getState() == needState);
        _;
    }

    constructor (address _store) public {
        changeStore(_store);
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
     * @dev Changes oracle store contract.
     * @param _store The new oracle store contract.
     */
    function changeStore(address _store) public onlyOwner {
        require (_store != 0x0);
        store = OracleStore(_store);
    }

    /**
     * @dev get contract state.
     */
    function getState() public view returns (State) {
        if (now - calcTime < ratePeriod)
            return State.PROCESSING_ORDERS;

        if (waitingOracles() != 0)
            return State.WAIT_ORACLES;

        if (readyOracles() >= MIN_READY_ORACLES)
            return State.CALC_RATES;

        return State.REQUEST_RATES;
    }

    /**
     * @dev Requests every oracle to get the actual rate.
     */
    function requestRates() payable public state(State.REQUEST_RATES) {
        require(store.oracleCount() >= MIN_ORACLES);
        uint256 sendValue = msg.value;

        for (address cur = store.firstOracle(); cur != 0x0; cur = store.getOracleNext(cur)) {
            OracleI oracle = OracleI(cur);
            uint callPrice = oracle.getPrice();
            if (cur.balance < callPrice) {
                sendValue = sendValue.sub(callPrice);
                cur.transfer(callPrice);
            }
            if (oracle.updateRate(0)) {
                emit OracleRequest(cur, store.getOracleName(cur));
            }
        } // foreach oracles
        requestTime = now;

        if (sendValue > 0)
            msg.sender.transfer(sendValue);
    }

    /**
     * @dev Get need money for oracles.
     */
    function requestPrice() public view returns (uint256) {
        uint256 requestCost = 0;
        for (address curr = store.firstOracle(); curr != 0x0; curr = store.getOracleNext(curr)) {
            OracleI oracle = OracleI(curr);
            uint callPrice = oracle.getPrice();
            if (curr.balance < callPrice) {
                requestCost += callPrice - curr.balance;
            }
        }
        return requestCost;
    }

    /**
     * @dev Calculates buy and sell rates after oracles have received it.
     */
    function calcRates() public state(State.CALC_RATES) {
        uint256 minimalRate = 2**256 - 1; // Max for UINT256
        uint256 maximalRate = 0;

        for (address cur = store.firstOracle(); cur != 0x0; cur = store.getOracleNext(cur)) {
            OracleI currentOracle = OracleI(cur);
            uint256 _rate = currentOracle.rate();
            if ((!currentOracle.waitQuery()) && (_rate != 0)) {
                minimalRate = Math.min256(_rate, minimalRate);
                maximalRate = Math.max256(_rate, maximalRate);
            }
        } // foreach oracles
        require(minimalRate >= MIN_RATE && maximalRate <= MAX_RATE);
        buyRate = minimalRate;
        sellRate = maximalRate;
        calcTime = now;
    }

    /**
     * @dev Gets oracle data.
     * @param _address Oracle address.
     */
    function getOracleData(address _address)
        public
        view
        returns (bytes32, bytes32, uint256, bool, uint256, address)
                /* name, type, upd_time, waiting, rate, next */
    {
        OracleI currentOracle = OracleI(_address);
        bytes32 _name = store.getOracleName(_address);
        address _next = store.getOracleNext(_address);

        return(
            _name,
            currentOracle.oracleType(),
            currentOracle.updateTime(),
            currentOracle.waitQuery(),
            currentOracle.rate(),
            _next
        );
    }

    /**
     * @dev Returns ready (which have data to be used) oracles count.
     */
    function readyOracles() public view returns (uint256) {
        uint256 count = 0;
        for (address current = store.firstOracle(); current != 0x0; current = store.getOracleNext(current)) {
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
        for (address current = store.firstOracle(); current != 0x0; current = store.getOracleNext(current)) {
            if (OracleI(current).waitQuery() && (now - requestTime) < oracleTimeout) {
                count++;
            }
        }
        return count;
    }

    /**
     * @dev Sends money to oracles and start requestRates.
     * @param fund Desired balance of every oracle.
     */
    function schedulerUpdateRate(uint256 fund) public {
        require(msg.sender == scheduler);
        for (address cur = store.firstOracle(); cur != 0x0; cur = store.getOracleNext(cur)) {
            cur.transfer((fund == 0) ? OracleI(cur).getPrice() : (fund));
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
}
