pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/math/Math.sol";
import "./zeppelin/lifecycle/Pausable.sol";
import "./interfaces/I_LibreToken.sol";
import "./interfaces/I_Oracle.sol";
import "./interfaces/I_Bank.sol";



contract ComplexBank is Pausable, BankI {
    using SafeMath for uint256;
    address public tokenAddress;
    LibreTokenI libreToken;
    
    // TODO; Check that all evetns used and delete unused
    event BuyOrderCreated(uint256 etherAmount);
    event SellOrderCreated(uint256 tokensAmount);
    event LogBuy(address senderAddress, address clientAddress, uint256 tokenAmount, uint256 cryptoAmount, uint256 buyPrice);
    event LogSell(address senderAddress, address clientAddress, uint256 tokenAmount, uint256 cryptoAmount, uint256 sellPrice);
    event OrderQueueGeneral(string description);
    event BuyOrderCanceled(uint256 orderId, address beneficiary, uint256 amount, uint256 parameter);
    event SellOrderCanceled(uint256 orderId, address beneficiary, uint256 amount, uint256 parameter);
    event SendEtherError(string error, address _addr);
    event BalanceRefill(address from, uint256 amount);
    
    uint256 constant MIN_READY_ORACLES = 1; //2;
    uint256 constant MIN_ORACLES_ENABLED = 1;//2;

    uint256 constant MAX_RELEVANCE_PERIOD = 48 hours;
    uint256 constant MIN_QUEUE_PERIOD = 10 minutes;

    uint256 constant REVERSE_PERCENT = 100;
    uint256 constant RATE_MULTIPLIER = 1000; // doubling in oracleBase __callback as parseIntRound(..., 3) as 3
    uint256 constant MAX_MINIMUM_BUY = 100 ether;
    uint256 constant MIN_MAXIMUM_BUY = 100 ether;
    uint256 constant MAX_MINIMUM_TOKENS_SELL = 400 * 100 * 10**18; // 100 ether * 400 usd/eth
    uint256 constant MIN_MAXIMUM_TOKENS_SELL = 400 * 100 * 10**18; // 100 ether * 400 usd/eth

    uint256 public relevancePeriod = 23 hours; // Минимальное время между calcRates() прошлого раунда
                                               // и requestUpdateRates() следующего
    uint256 public queuePeriod = 60 minutes;
    uint256 public balanceEtherCap = 10 ether; // Contract balance ether cap.
    // после тестов убрать public
    uint256 public timeUpdateRequest = 0; // the time of requestUpdateRates()
    address public withdrawWallet; // Multisig withdraw wallet address
    bool public autoWithdraw = true;

    enum ProcessState {
        REQUEST_UPDATE_RATES,
        CALC_RATE,
        PROCESS_ORDERS,
        ORDER_CREATION
    }

    ProcessState public contractState;

    modifier canStartEmission() {
        require((now >= timeUpdateRequest + relevancePeriod) || (contractState == ProcessState.REQUEST_UPDATE_RATES));
        _;
        contractState = ProcessState.CALC_RATE;
        timeUpdateRequest = now;
    }

    modifier calcRatesAllowed() {
        require(contractState == ProcessState.CALC_RATE);

        processWaitingOracles(); // выкинет если есть оракулы, ждущие менее 10 минут
        if (numReadyOracles() < MIN_READY_ORACLES) {
            contractState = ProcessState.REQUEST_UPDATE_RATES;
            OracleProblem("Not enough ready oracles. Please, request update rates again");
            return;
        }
        
        _;
        
        if (sellNextOrder == 0 && buyNextOrder == 0)
            contractState = ProcessState.ORDER_CREATION;
        else
            contractState = ProcessState.PROCESS_ORDERS;
    }

    modifier queueProcessingAllowed() {
        require(contractState == ProcessState.PROCESS_ORDERS);
        _;
        if ((sellNextOrder == 0 && buyNextOrder == 0) || (now >= timeUpdateRequest + queuePeriod))
            contractState = ProcessState.ORDER_CREATION;
    }

    modifier orderCreationAllowed() {
        require((contractState == ProcessState.ORDER_CREATION) || (now >= timeUpdateRequest + queuePeriod));
        _;
        contractState = ProcessState.ORDER_CREATION;
    }

// for tests
    function timeSinceUpdateRequest() public view returns (uint256) { return now - timeUpdateRequest; }
// end for tests

    struct Limit {
        uint256 min;
        uint256 max;
    }

    // Limits start
    Limit public buyLimit = Limit(1 wei, 99999 * 1 ether);
    Limit public sellLimit = Limit(1 wei, 99999 * 1 ether);
    // Limits end

    // 01-emission start

    /**
     * @dev Creates buy order.
     * @param _address Beneficiar.
     * @param _rateLimit Max affordable buying rate, 0 to allow all.
     */
    function createBuyOrder(address _address, uint256 _rateLimit) payable public whenNotPaused orderCreationAllowed {
        require((msg.value >= buyLimit.min) && (msg.value <= buyLimit.max));
        require(_address != 0x0);
        if (buyNextOrder == buyOrders.length) {
            buyOrders.length += 1;
        }
        buyOrders[buyNextOrder++] = OrderData({
            senderAddress: msg.sender,
            recipientAddress: _address,
            orderAmount: msg.value,
            orderTimestamp: now,
            rateLimit: _rateLimit
        });
        BuyOrderCreated(msg.value);
        withdraw();
    }

    /**
     * @dev Creates buy order.
     * @param _rateLimit Max affordable buying rate, 0 to allow all.
     */
    function createBuyOrder(uint256 _rateLimit) payable public whenNotPaused orderCreationAllowed {
        createBuyOrder(msg.sender, _rateLimit);
    }

    /**
     * @dev Creates sell order.
     * @param _address Beneficiar.
     * @param _tokensCount Amount of tokens to sell.
     * @param _rateLimit Min affordable selling rate, 0 to allow all.
     */
    function createSellOrder(address _address, uint256 _tokensCount, uint256 _rateLimit) public whenNotPaused orderCreationAllowed {
        require((_tokensCount >= sellLimit.min) && (_tokensCount <= sellLimit.max));
        require(_address != 0x0);
        address tokenOwner = msg.sender;
        require(_tokensCount <= libreToken.balanceOf(tokenOwner));
        if (sellNextOrder == sellOrders.length) {
            sellOrders.length += 1;
        }
        sellOrders[sellNextOrder++] = OrderData({
            senderAddress: tokenOwner,
            recipientAddress: _address,
            orderAmount: _tokensCount,
            orderTimestamp: now,
            rateLimit: _rateLimit
        });
        libreToken.burn(tokenOwner, _tokensCount);
        SellOrderCreated(_tokensCount); 
    }

    /**
     * @dev Creates sell order.
     * @param _tokensCount Amount of tokens to sell.
     * @param _rateLimit Min affordable selling rate, 0 to allow all.
     */
    function createSellOrder(uint256 _tokensCount, uint256 _rateLimit) public whenNotPaused orderCreationAllowed {
        createSellOrder(msg.sender, _tokensCount, _rateLimit);
    }

    /**
     * @dev Fallback function.
     */
    function () whenNotPaused orderCreationAllowed payable external {
        createBuyOrder(msg.sender, 0); // 0 - без ценовых ограничений
    }

    /**
     * @dev Sets min buy sum (in Wei).
     * @param _minBuyLimit - min buy sum in Wei.
     */
    function setMinBuyLimit(uint _minBuyLimit) public onlyOwner {
        require((_minBuyLimit <= MAX_MINIMUM_BUY) && (_minBuyLimit > 0));
        buyLimit.min = _minBuyLimit;
    }

    /**
     * @dev Sets max buy sum (in Wei).
     * @param _maxBuyLimit - max buy sum in Wei.
     */
    function setMaxBuyLimit(uint _maxBuyLimit) public onlyOwner {
        require(_maxBuyLimit >= MIN_MAXIMUM_BUY);
        buyLimit.max = _maxBuyLimit;
    }

    /**
     * @dev Sets min sell tokens amount.
     * @param _minSellLimit - min sell tokens.
     */
    function setMinSellLimit(uint _minSellLimit) public onlyOwner {
        require((_minSellLimit <= MAX_MINIMUM_TOKENS_SELL) && (_minSellLimit > 0));
        sellLimit.min = _minSellLimit;
    }
    
    /**
     * @dev Sets max sell tokens amount.
     * @param _maxSellLimit - max sell tokens.
     */
    function setMaxSellLimit(uint _maxSellLimit) public onlyOwner {
        require(_maxSellLimit >= MIN_MAXIMUM_TOKENS_SELL);
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

    OrderData[] private buyOrders; // очередь ордеров на покупку
    OrderData[] private sellOrders; // очередь ордеров на продажу
    uint256 buyOrderIndex = 0; // Хранит первый номер ордера
    uint256 sellOrderIndex = 0;

    uint256 private buyNextOrder = 0; // Хранит следующий за последним номер ордера
    uint256 private sellNextOrder = 0;

    mapping (address => uint256) balanceEther; // возврат средств
    uint256 overallRefundValue = 0;

    /**
     * @dev Sends refund.
     */
    function getEther() public {
        require(balanceEther[msg.sender] > 0);
        // TODO: учесть средства на контракте кошелька и как-то их получить при необходимости или запросить
        uint256 sendBalance = balanceEther[msg.sender];
        if (this.balance < sendBalance) {
            sendBalance = this.balance;
            SendEtherError("The contract doesn't have enough funds, the payment will be fulfilled partly", msg.sender);
        }

        if (msg.sender.send(sendBalance)) {
            overallRefundValue = overallRefundValue.sub(sendBalance);
            balanceEther[msg.sender] -= sendBalance;
        }
        else
            SendEtherError("Error sending money", msg.sender);
    }

    /**
     * @dev Gets the possible refund amount.
     */
    function getBalanceEther() public view returns (uint256) {
        return balanceEther[msg.sender];
    }

    /**
     * @dev Gets the possible refund amount for owner
     */
    function getBalanceEther(address _address) public view onlyOwner returns (uint256) {
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
        BuyOrderCanceled(_orderID, sender, orderAmount, _parameter);
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
        
        sellOrders[_orderID].recipientAddress = 0x0; // Mark order as completed or canceled
        SellOrderCanceled(_orderID, sender, tokensAmount, _parameter);
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
            buyOrders[_orderID].recipientAddress = 0x0; // Mark order as completed or canceled
            libreToken.mint(recipientAddress, tokensAmount);
            LogBuy(senderAddress, recipientAddress, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
        }
    }

    /**
     * @dev Fill buy orders queue (alias with no order limit).
     */
    function processBuyQueue() public whenNotPaused queueProcessingAllowed {
        return processBuyQueue(0);
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
            OrderQueueGeneral("Order queue for buy cleared");
        } else {
            buyOrderIndex = lastOrder;
            OrderQueueGeneral("The order queue for buy is not cleared up to the end");
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
            LogSell(senderAddress, recipientAddress, tokensAmount, cryptoAmount, cryptoFiatRateSell);
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
            OrderQueueGeneral("Order queue for sell cleared");
        } else {
            sellOrderIndex = lastOrder;
            OrderQueueGeneral("The order queue for sell is not cleared up to the end");
        }
    }
    // 02-queue end


    // admin start
    // C идеологической точки зрения давать такие привилегии админу может быть неправильно
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
    function getBuyOrder(uint256 _orderID) public onlyOwner view returns (address, address, uint256, uint256, uint256) {
        require((buyNextOrder > 0) && (buyNextOrder >= _orderID) && (buyOrderIndex <= _orderID));
        return (buyOrders[_orderID].senderAddress, buyOrders[_orderID].recipientAddress,
                buyOrders[_orderID].orderAmount, buyOrders[_orderID].orderTimestamp,
                buyOrders[_orderID].rateLimit);
    }

    /**
     * @dev Gets sell order (by the owner).
     * @param _orderID The order ID.
     */
    function getSellOrder(uint256 _orderID) public onlyOwner view returns (address, address, uint256, uint256, uint256) {
        require((sellNextOrder > 0) && (sellNextOrder >= _orderID) && (sellOrderIndex <= _orderID));
        return (sellOrders[_orderID].senderAddress, sellOrders[_orderID].recipientAddress,
                sellOrders[_orderID].orderAmount, sellOrders[_orderID].orderTimestamp,
                sellOrders[_orderID].rateLimit);
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
        libreToken = LibreTokenI(tokenAddress);
    }

    // admin end


    // 03-oracles methods start
    event OracleAdded(address indexed _address, bytes32 name);
    event OracleEnabled(address indexed _address, bytes32 name);
    event OracleDisabled(address indexed _address, bytes32 name);
    event OracleDeleted(address indexed _address, bytes32 name);
    event OraclesTouched(string message);
    event OracleTouched(address indexed _address, bytes32 name);
    event OracleNotTouched(address indexed _address, bytes32 name);
    event OracleProblem(string description);
    

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
    uint256 public cryptoFiatRate;
    uint256 public buyFee = 0;
    uint256 public sellFee = 0;
    uint256 constant MAX_FEE = 7000; // 70%

    address public scheduler;

    /**
     * @dev Gets oracle data.
     * @param _address Oracle address.
     */
    function getOracleData(address _address) public view returns (bytes32, bytes32, uint256, bool, bool, uint256, address) {
                                                                /* name, type, upd_time, enabled, waiting, rate, next */
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
            if ((currentOracle.rate() != 0) && !currentOracle.waitQuery() ) 
                numOracles++;
        }
        return numOracles;
    }

    /**
     * @dev Lets owner to set relevance period.
     * @param _period Period up to MAX_RELEVANCE_PERIOD hours.
     */
    function setRelevancePeriod(uint256 _period) public onlyOwner {
        require(_period <= MAX_RELEVANCE_PERIOD);
        relevancePeriod = _period;
    }

    /**
     * @dev Lets owner to set queue period.
     * @param _period Period from MIN_QUEUE_PERIOD.
     */
    function setQueuePeriod(uint256 _period) public onlyOwner {
        require(_period >= MIN_QUEUE_PERIOD);
        queuePeriod = _period;
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
        
        delete oracles[_address];
        countOracles--;
        if (oracles[_address].enabled)
            numEnabledOracles--;
    }

    /**
     * @dev Sends money to oracles and start requestUpdateRates.
     */
    function schedulerUpdateRate() public {
        schedulerUpdateRate(0);
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
        uint256 curBalance = this.balance + withdrawWallet.balance;
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
    function requestUpdateRates() public payable canStartEmission {
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
                        OracleTouched(cur, oracles[cur].name);
                    else {
                        OracleNotTouched(cur, oracles[cur].name);
                        continue;
                    }
                }
            }
        } // foreach oracles
        OraclesTouched("Rate update started");
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
                // если оракул ждёт 10 минут и больше
                if (currentOracle.updateTime() < now - 10 minutes) {
                    currentOracle.clearState(); // но не ждать
                } else {
                    revert(); // не даём завершить, пока есть ждущие менее 10 минут оракулы
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
            if ((currentOracleData.enabled) && ( !currentOracle.waitQuery()) && (_rate != 0)) {
                minimalRate = Math.min256(_rate, minimalRate);
                maximalRate = Math.max256(_rate, maximalRate);
            }
        } // foreach oracles

        cryptoFiatRate = minimalRate.add(maximalRate) / 2;
        cryptoFiatRateBuy = minimalRate.mul(REVERSE_PERCENT * RATE_MULTIPLIER - buyFee * RATE_MULTIPLIER / REVERSE_PERCENT) / REVERSE_PERCENT / RATE_MULTIPLIER;
        cryptoFiatRateSell = maximalRate.mul(REVERSE_PERCENT * RATE_MULTIPLIER + sellFee * RATE_MULTIPLIER / REVERSE_PERCENT) / REVERSE_PERCENT / RATE_MULTIPLIER;
    }
    // 04-spread calc end

    // 05-monitoring start

    // 05-monitoring end
    
    // 08-helper methods start
    
    // 08-helper methods end



    // system methods start

    /**
     * @dev Returns total token count.
     */
    function totalTokenCount() public view returns (uint256) {
        return libreToken.totalSupply();
    }

    // TODO: удалить после тестов, нужен чтобы возвращать эфир с контракта
    /**
     * @dev Withdraws all the balance to owner.
     */
    function withdrawBalance() public onlyOwner {
        owner.transfer(this.balance);
    }

     /**
     * @dev Sets balance cap limit balance above cap.
     * @param capInWei - balance cap sum in Wei (1 ether = 10^18 wei)
     */
    function setBalanceCap(uint256 capInWei) public onlyOwner {
        require(capInWei > 0);
        balanceEtherCap = capInWei;
        withdraw();
    }

    /**
     * @dev Withdraws balance above cap.
     */
    function withdraw() internal {
        if ((!autoWithdraw) || (this.balance <= balanceEtherCap))
            return;
        withdrawWallet.transfer(this.balance - balanceEtherCap);
    }


    /**
     * @dev Sets wallet to withdraw balance above cap cap
     * @param withdrawTo - wallet to withdraw ether
     */
    function setWithdrawWallet(address withdrawTo) public onlyOwner {
        require(withdrawTo != 0x0);
        withdrawWallet = withdrawTo; 
    }

     /**
     * @dev Used to refill contract balance (eg. from escrow multisig wallet.)
     */
    function refillBalance() public payable {
        BalanceRefill(msg.sender, msg.value);
        withdraw();
    }
    // system methods end
    
    /**
     * @dev Used to set auto-widthdraw status of contract balance to multisig
     * @param _autoWithdraw Bool flag of auto-withdraw status.
     */
    function setAutoWithdraw(bool _autoWithdraw) public onlyOwner {
        autoWithdraw = _autoWithdraw;
    }

}