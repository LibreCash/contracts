pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/math/Math.sol";
import "./zeppelin/lifecycle/Pausable.sol";
import "./interfaces/I_Oracle.sol";
import "./interfaces/I_Bank.sol";
import "./token/LibreCash.sol";

contract ComplexBank is Pausable, BankI {
    using SafeMath for uint256;
    address public tokenAddress;
    LibreCash libreToken;
    
    event BuyOrder(address sender, address recipient, uint256 tokenAmount, uint256 price);
    event SellOrder(address sender, address recipient, uint256 cryptoAmount, uint256 price);
    event SellQueueProcessed();
    event BuyQueueProcessed();
    event NotEnoughMoney(address recipient);
    event ErrorSendingEther(address recipient);
    event BuyOrderCancelled(uint256 orderId, address sender, uint256 cryptoAmount, uint256 parameter);
    event SellOrderCancelled(uint256 orderId, address sender, uint256 tokenAmount, uint256 parameter);
    
    uint256 constant MIN_READY_ORACLES = 2;
    uint256 constant MIN_ORACLES_ENABLED = 2;
    uint256 constant REVERSE_PERCENT = 100;
    uint256 constant RATE_MULTIPLIER = 1000; // doubling in oracleBase __callback as parseIntRound(..., 3) as 3

    uint256 public relevancePeriod = 23 hours;
    uint256 public queuePeriod = 60 minutes;
    uint256 public timeUpdateRequest = 0; // the time of requestUpdateRates()
    uint256 public oracleTimeout = 10 minutes; // Timeout to wait oracle data

    enum ProcessState {
        REQUEST_UPDATE_RATES,
        CALC_RATE,
        PROCESS_ORDERS,
        ORDER_CREATION
    }

    ProcessState public contractState;

    modifier canStartEmission() {
        require((now >= timeUpdateRequest + relevancePeriod) || 
                (contractState == ProcessState.REQUEST_UPDATE_RATES));
        _;
        contractState = ProcessState.CALC_RATE;
        timeUpdateRequest = now;
    }

    modifier calcRatesAllowed() {
        require(contractState == ProcessState.CALC_RATE);

        processWaitingOracles(); // revert transaction if has oracles waiting less then 10 min.
        if (numReadyOracles() < MIN_READY_ORACLES) {
            contractState = ProcessState.REQUEST_UPDATE_RATES;
            OracleError("Not enough ready oracles. Please, request update rates again");
            return;
        }
        
        _;
        bool ordersProcessed = (sellNextOrder == 0) && (buyNextOrder == 0);
        contractState = ordersProcessed ? ProcessState.ORDER_CREATION : ProcessState.PROCESS_ORDERS;
    }

    modifier queueProcessingAllowed() {
        require((contractState == ProcessState.PROCESS_ORDERS) && 
                (now <= timeUpdateRequest + queuePeriod));
        _;
        bool ordersProcessed = (sellNextOrder == 0) && (buyNextOrder == 0);
        if (ordersProcessed)
            contractState = ProcessState.ORDER_CREATION;
    }

    modifier orderCreationAllowed() {
        require((contractState == ProcessState.ORDER_CREATION) || 
                (now > timeUpdateRequest + queuePeriod));
        _;
        contractState = ProcessState.ORDER_CREATION;
    }

    struct Limit {
        uint256 min;
        uint256 max;
    }

    Limit public buyLimit = Limit(1 wei, 99999 * 1 ether);
    Limit public sellLimit = Limit(1 wei, 99999 * 1 ether);

    // 01-emission start

    /**
     * @dev Creates buy order.
     * @param _recipient Recipient.
     * @param _rateLimit Max affordable buying rate, 0 to allow all.
     */
    function createBuyOrder(address _recipient, uint256 _rateLimit) payable public whenNotPaused orderCreationAllowed {
        require((_recipient != 0x0) && (msg.value >= buyLimit.min) && (msg.value <= buyLimit.max));

        if (buyNextOrder == buyOrders.length) {
            buyOrders.length++;
        }
        buyOrders[buyNextOrder++] = OrderData({
            senderAddress: msg.sender,
            recipientAddress: _recipient,
            orderAmount: msg.value,
            orderTimestamp: now,
            rateLimit: _rateLimit
        });
    }

    /**
     * @dev Creates sell order.
     * @param _recipient Recipient.
     * @param _tokensCount Amount of tokens to sell.
     * @param _rateLimit Min affordable selling rate, 0 to allow all.
     */
    function createSellOrder(address _recipient, uint256 _tokensCount, uint256 _rateLimit) public whenNotPaused orderCreationAllowed {
        require((_recipient != 0x0) && (_tokensCount >= sellLimit.min) && (_tokensCount <= sellLimit.max));
        address tokenOwner = msg.sender;
        require(_tokensCount <= libreToken.allowance(tokenOwner,this));
        libreToken.transferFrom(tokenOwner, this, _tokensCount);
        libreToken.burn(_tokensCount);

        if (sellNextOrder == sellOrders.length) {
            sellOrders.length++;
        }
        sellOrders[sellNextOrder++] = OrderData({
            senderAddress: tokenOwner,
            recipientAddress: _recipient,
            orderAmount: _tokensCount,
            orderTimestamp: now,
            rateLimit: _rateLimit
        });
    }

    /**
     * @dev Fallback function.
     */
    function() external whenNotPaused orderCreationAllowed payable {
        createBuyOrder(msg.sender, 0); // 0 - without price limits
    }

    /**
     * @dev Sets max buy sum (in Wei).
     * @param _minBuyLimit - min buy sum in Wei.
     * @param _maxBuyLimit - max buy sum in Wei.
     */
    function setBuyLimits(uint _minBuyLimit, uint _maxBuyLimit) public onlyOwner {
        buyLimit.min = _minBuyLimit;
        buyLimit.max = _maxBuyLimit;
    }

    
    /**
     * @dev Sets max sell tokens amount.
     * @param _maxSellLimit - max sell tokens.
     * @param _minSellLimit - min sell tokens.
     */
    function setSellLimits(uint _minSellLimit, uint _maxSellLimit) public onlyOwner {
        sellLimit.min = _minSellLimit;
        sellLimit.max = _maxSellLimit;
    }

    // 01-emission end

    // 02-queue start
    struct OrderData {
        address senderAddress;
        address recipientAddress;
        uint256 orderAmount;
        uint256 orderTimestamp;
        uint256 rateLimit;
    }

    OrderData[] private buyOrders; // buy orders queue
    OrderData[] private sellOrders; // sell orders queue
    uint256 buyOrderIndex = 0; // store number of first order
    uint256 sellOrderIndex = 0;

    uint256 private buyNextOrder = 0; // store number order after last
    uint256 private sellNextOrder = 0;

    mapping (address => uint256) balanceEther; // internal
    uint256 overallRefundValue = 0;

    /**
     * @dev Sends refund.
     */
    function claimBalance() public {
        require(balanceEther[msg.sender] > 0);
        uint256 sendBalance = balanceEther[msg.sender];
        
        if (this.balance < sendBalance) {
            sendBalance = this.balance;
            NotEnoughMoney(msg.sender);
        }

        overallRefundValue = overallRefundValue.sub(sendBalance);
        balanceEther[msg.sender] -= sendBalance;
        
        if ( !msg.sender.send(sendBalance)) {
            overallRefundValue = overallRefundValue.add(sendBalance);
            balanceEther[msg.sender] += sendBalance;
            ErrorSendingEther(msg.sender);
        }
    }

     /**
     * @dev Gets the possible refund amount.
     */
    function getBalance() public view returns (uint256) {
        return balanceEther[msg.sender];
    }

    /**
     * @dev Gets the possible refund amount for owner
     */
    function getBalance(address _address) public view onlyOwner returns (uint256) {
        return balanceEther[_address];
    }

    /**
     * @dev Cancels buy order.
     * @param _orderID The ID of order.
     * @param _parameter More information on cancellation (for example, order limit).
     */
    function cancelBuyOrder(uint256 _orderID, uint256 _parameter) private returns (bool) {
        if (buyOrders[_orderID].recipientAddress == 0x0)
            return false;

        address sender = buyOrders[_orderID].senderAddress;
        uint256 orderAmount = buyOrders[_orderID].orderAmount;

        balanceEther[sender] = balanceEther[sender].add(orderAmount);
        buyOrders[_orderID].recipientAddress = 0x0; // Mark order as completed or cancelled
        BuyOrderCancelled(_orderID, sender, orderAmount, _parameter);
        overallRefundValue = overallRefundValue.add(orderAmount);

        return true;
    }
    
    /**
     * @dev Cancels sell order.
     * @param _orderID The ID of order.
     * @param _parameter More information on cancellation (for example, order limit).
     */
    function cancelSellOrder(uint256 _orderID, uint256 _parameter) private returns(bool) {
        if (sellOrders[_orderID].recipientAddress == 0x0)
            return false;

        address sender = sellOrders[_orderID].senderAddress;
        uint256 tokensAmount = sellOrders[_orderID].orderAmount;
        
        sellOrders[_orderID].recipientAddress = 0x0; // Mark order as completed or cancelled
        SellOrderCancelled(_orderID, sender, tokensAmount, _parameter);
        libreToken.mint(sender, tokensAmount);
        return true;
    }

    /**
     * @dev Fills buy order from queue.
     * @param _orderID The order ID.
     */
    function processBuyOrder(uint256 _orderID) internal {
        if (buyOrders[_orderID].recipientAddress == 0x0)
            return;

        uint256 cryptoAmount = buyOrders[_orderID].orderAmount;
        uint256 tokensAmount = cryptoAmount.mul(cryptoFiatRateBuy) / RATE_MULTIPLIER;
        address senderAddress = buyOrders[_orderID].senderAddress;
        address recipientAddress = buyOrders[_orderID].recipientAddress;
        uint256 maxRate = buyOrders[_orderID].rateLimit;

        if ((maxRate != 0) && (cryptoFiatRateBuy > maxRate)) {
            cancelBuyOrder(_orderID, maxRate);
        } else {
            buyOrders[_orderID].recipientAddress = 0x0; // Mark order as completed or cancelled
            libreToken.mint(recipientAddress, tokensAmount);
            BuyOrder(senderAddress, recipientAddress, tokensAmount, cryptoFiatRateBuy);
        }
    }

    /**
     * @dev Fill buy orders queue.
     * @param _limit Order limit.
     */
    function processBuyQueue(uint256 _limit) public whenNotPaused queueProcessingAllowed {
        bool processAll = ((_limit == 0) || ((buyOrderIndex + _limit) > buyNextOrder));
        uint256 lastOrder = processAll ? buyNextOrder : buyOrderIndex + _limit;

        for (uint i = buyOrderIndex; i < lastOrder; i++) {
            processBuyOrder(i);
        }

        if (lastOrder == buyNextOrder) {
            buyOrderIndex = 0;
            buyNextOrder = 0;
            BuyQueueProcessed();
        } else {
            buyOrderIndex = lastOrder;
        }
    }

    /**
     * @dev Fills sell order from queue.
     * @param _orderID The order ID.
     */
    function processSellOrder(uint256 _orderID) internal {
        if (sellOrders[_orderID].recipientAddress == 0x0)
            return;
        
        address recipientAddress = sellOrders[_orderID].recipientAddress;
        address senderAddress = sellOrders[_orderID].senderAddress;
        uint256 tokensAmount = sellOrders[_orderID].orderAmount;
        uint256 cryptoAmount = tokensAmount.mul(RATE_MULTIPLIER) / cryptoFiatRateSell;
        uint256 minRate = sellOrders[_orderID].rateLimit;

        if ((minRate != 0) && (cryptoFiatRateSell < minRate)) {
            cancelSellOrder(_orderID, minRate);
        } else {
            balanceEther[recipientAddress] = balanceEther[recipientAddress].add(cryptoAmount);
            overallRefundValue = overallRefundValue.add(cryptoAmount);
            SellOrder(senderAddress, recipientAddress, cryptoAmount, cryptoFiatRateSell);
        }      
    }

    /**
     * @dev Fill sell orders queue.
     * @param _limit Order limit.
     */
    function processSellQueue(uint256 _limit) public whenNotPaused queueProcessingAllowed {
        bool processAll = ((_limit == 0) || ((sellOrderIndex + _limit) > sellNextOrder));
        uint256 lastOrder = processAll ? sellNextOrder : sellOrderIndex + _limit;
                
        for (uint i = sellOrderIndex; i < lastOrder; i++) {
            processSellOrder(i);
        }

        if (lastOrder == sellNextOrder) {
            sellOrderIndex = 0;
            sellNextOrder = 0;
        } else {
            sellOrderIndex = lastOrder;
            SellQueueProcessed();
        }
    }
    // 02-queue end


    // admin start
    /**
     * @dev Cancels buy order (by the owner).
     * @param _orderID The order ID.
     */
    function cancelBuyOrderOwner(uint256 _orderID) public onlyOwner {
        if (!cancelBuyOrder(_orderID, 0))
            revert();
    }

    /**
     * @dev Cancels sell order (by the owner).
     * @param _orderID The order ID.
     */
    function cancelSellOrderOwner(uint256 _orderID) public onlyOwner {
        if (!cancelSellOrder(_orderID, 0))
            revert();
    }

    /**
     * @dev Gets buy order (by the owner).
     * @param _orderID The order ID.
     */
    function getBuyOrder(uint256 _orderID) public view returns (address, address, uint256, uint256, uint256) {
        require(msg.sender == owner || msg.sender == buyOrders[_orderID].senderAddress);
        require((buyNextOrder > 0) && (buyNextOrder >= _orderID) && (buyOrderIndex <= _orderID));
        return (buyOrders[_orderID].senderAddress, buyOrders[_orderID].recipientAddress,
                buyOrders[_orderID].orderAmount, buyOrders[_orderID].orderTimestamp,
                buyOrders[_orderID].rateLimit);
    }

    /**
     * @dev Gets sell order (by the owner).
     * @param _orderID The order ID.
     */
    function getSellOrder(uint256 _orderID) public view returns (address, address, uint256, uint256, uint256) {
        require(msg.sender == owner || msg.sender == sellOrders[_orderID].senderAddress);
        require((sellNextOrder > 0) && (sellNextOrder >= _orderID) && (sellOrderIndex <= _orderID));
        return (sellOrders[_orderID].senderAddress, sellOrders[_orderID].recipientAddress,
                sellOrders[_orderID].orderAmount, sellOrders[_orderID].orderTimestamp,
                sellOrders[_orderID].rateLimit);
    }

    /**
     * @dev Gets user orders.
     */
    function getMyOrders() public view returns(uint[], uint[]) {
        uint count = 0;
        for (uint256 i = buyOrderIndex; i < buyNextOrder; i++) {
            if (buyOrders[i].recipientAddress != 0x0 && buyOrders[i].senderAddress == msg.sender)
                count++;
        }

        uint[] memory myBuy = new uint[](count);
        count = 0;
        for (i = buyOrderIndex; i < buyNextOrder; i++) {
            if (buyOrders[i].recipientAddress != 0x0 && buyOrders[i].senderAddress == msg.sender)
                myBuy[count++] = i;
        }

        count = 0;
        for (i = sellOrderIndex; i < sellNextOrder; i++) {
            if (sellOrders[i].recipientAddress != 0x0 && sellOrders[i].senderAddress == msg.sender) 
                count++;
        }

        uint[] memory mySell = new uint[](count);
        count = 0;
        for (i = sellOrderIndex; i < sellNextOrder; i++) {
            if (sellOrders[i].recipientAddress != 0x0 && sellOrders[i].senderAddress == msg.sender) 
                mySell[count++] = i;
        }
        return (myBuy, mySell);
    }

    /**
     * @dev Gets sell order count.
     */
    function getSellOrdersCount() public view returns(uint256) {
        uint256 count = 0;
        for (uint256 i = sellOrderIndex; i < sellNextOrder; i++) {
            if (sellOrders[i].recipientAddress != 0x0) 
                count++;
        }
        return count;
    }

    /**
     * @dev Gets buy order count.
     */
    function getBuyOrdersCount() public view returns(uint256) {
        uint256 count = 0;
        for (uint256 i = buyOrderIndex; i < buyNextOrder; i++) {
            if (buyOrders[i].recipientAddress != 0x0) 
                count++;
        }
        return count;
    }
    
    /**
     * @dev Attaches token contract.
     * @param _tokenAddress The token address.
     */
    function attachToken(address _tokenAddress) public onlyOwner {
        require(_tokenAddress != 0x0);
        tokenAddress = _tokenAddress;
        libreToken = LibreCash(tokenAddress);
    }

    // admin end


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

    uint256 public cryptoFiatRateBuy = 1000;
    uint256 public cryptoFiatRateSell = 1000;
    uint256 public buyFee = 0;
    uint256 public sellFee = 0;
    uint256 constant MAX_FEE = 7000; // 70%

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
    function numReadyOracles() public view returns (uint256) {
        uint256 numOracles = 0;
        for (address current = firstOracle; current != 0x0; current = oracles[current].next) {
            if (!oracles[current].enabled) 
                continue;
            OracleI currentOracle = OracleI(current);
            if ((currentOracle.rate() != 0) && (!currentOracle.waitQuery())) 
                numOracles++;
        }
        return numOracles;
    }

    /**
     * @dev Lets owner to set relevance period.
     * @param _period Period up to MAX_RELEVANCE_PERIOD hours.
     */
    function setRelevancePeriod(uint256 _period) public onlyOwner {
        relevancePeriod = _period;
    }

    /**
     * @dev Lets owner to set queue period.
     * @param _period Period from MIN_QUEUE_PERIOD.
     */
    function setQueuePeriod(uint256 _period) public onlyOwner {
        queuePeriod = _period;
    }

    /**
     * @dev Lets owner to set  Oracle timeout period.
     * @param _period Oracle data waiting timeout.
     */
    function setOracleTimeout(uint256 _period) public onlyOwner {
        oracleTimeout = _period;
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
            uint256 maximalOracleRate = cryptoFiatRateSell.mul(RATE_MULTIPLIER).mul(REVERSE_PERCENT) / (RATE_MULTIPLIER * REVERSE_PERCENT + sellFee * RATE_MULTIPLIER / REVERSE_PERCENT);
            sellFee = _sellFee;
            cryptoFiatRateSell = maximalOracleRate.mul(RATE_MULTIPLIER * REVERSE_PERCENT + sellFee * RATE_MULTIPLIER / REVERSE_PERCENT) / (RATE_MULTIPLIER * REVERSE_PERCENT);
        }
        if (buyFee != _buyFee) {
            uint256 minimalOracleRate = cryptoFiatRateBuy.mul(RATE_MULTIPLIER * REVERSE_PERCENT) / (RATE_MULTIPLIER * REVERSE_PERCENT - buyFee * RATE_MULTIPLIER / REVERSE_PERCENT);
            buyFee = _buyFee;
            cryptoFiatRateBuy = minimalOracleRate.mul(RATE_MULTIPLIER * REVERSE_PERCENT - buyFee * RATE_MULTIPLIER / REVERSE_PERCENT) / (RATE_MULTIPLIER * REVERSE_PERCENT);
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
     * @dev Sends money to oracles and start requestUpdateRates.
     * @param fund Desired balance of every oracle.
     */
    function schedulerUpdateRate(uint256 fund) public {
        require(msg.sender == scheduler);
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (oracles[cur].enabled)
                cur.transfer((fund == 0) ? (OracleI(cur).getPrice()) : (fund));
        }
        requestUpdateRates();
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
    function getOracleDeficit() public view returns (uint256) {
        uint256 deficit = 0;
        for (address curr = firstOracle; curr != 0x0; curr = oracles[curr].next) {
            if (oracles[curr].enabled) {
                OracleI oracle = OracleI(curr);
                uint callPrice = oracle.getPrice();
                if (curr.balance < callPrice) {
                    deficit += callPrice - curr.balance;
                }
            }   
        }
        return deficit;
    }

    /**
     * @dev Gets bank reserve.
     */
    function getReservePercent() public view returns (uint256) {
        uint256 reserve = 0;
        uint256 curBalance = this.balance;
        if ((curBalance != 0) && (cryptoFiatRateSell != 0)) {
            uint256 reserveBalance = curBalance;
            for (uint i = buyOrderIndex; i < buyNextOrder; i++) {
                if (buyOrders[i].recipientAddress != 0x0) {
                    reserveBalance = reserveBalance.sub(buyOrders[i].orderAmount);
                }
            }
            reserveBalance = reserveBalance.sub(overallRefundValue);
            uint256 canGetCryptoBySellingTokens = (libreToken.totalSupply() * RATE_MULTIPLIER) / cryptoFiatRateSell;
            reserve = (reserveBalance * REVERSE_PERCENT * 100) / canGetCryptoBySellingTokens;
        }
        return reserve;
    }

    /**
     * @dev Requests every enabled oracle to get the actual rate.
     */
    function requestUpdateRates() payable public canStartEmission {
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
                if (!oracle.waitQuery()) {
                    if (oracle.updateRate())
                        OracleRequest(cur, oracles[cur].name);
                }
            }
        } // foreach oracles
    }

    /**
     * @dev Clears too-long-waiting oracles.
     */
    function processWaitingOracles() internal {
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (!oracles[cur].enabled) 
                continue;

            OracleI currentOracle = OracleI(cur);
            if (currentOracle.waitQuery()) {
                // If oracle wait more then 10 mins
                if (currentOracle.updateTime() < now - 10 minutes) {
                    currentOracle.clearState(); // Reset Oracle State
                } else {
                // If have oracles waited less than TIMEOUT - revert transaction
                    revert();
                }
            }
        } // foreach oracles
    }

     // 03-oracles methods end


    // 04-spread calc start 
    /**
     * @dev Processes data from ready oracles to get rates.
     */
    function calcRates() public calcRatesAllowed {
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
        cryptoFiatRateBuy = minimalRate.mul(REVERSE_PERCENT * RATE_MULTIPLIER - buyFee * RATE_MULTIPLIER / REVERSE_PERCENT) / REVERSE_PERCENT / RATE_MULTIPLIER;
        cryptoFiatRateSell = maximalRate.mul(REVERSE_PERCENT * RATE_MULTIPLIER + sellFee * RATE_MULTIPLIER / REVERSE_PERCENT) / REVERSE_PERCENT / RATE_MULTIPLIER;
    }
    // 04-spread calc end

    // system methods start

    /**
     * @dev Returns current token's total count.
     */
    function totalTokenCount() public view returns (uint256) {
        return libreToken.totalSupply();
    }

    /**
     * @dev set new owner.
     * @param newOwner The new owner for libreToken.
     */
    function transferTokenOwner(address newOwner) public onlyOwner {
        libreToken.transferOwnership(newOwner);
    }

    // TODO: Delete after tests. Used to withdraw balance in test network
    /**
     * @dev Withdraws all the balance to owner.
     */
    function withdrawBalance() public onlyOwner {
        owner.transfer(this.balance);
    }
}