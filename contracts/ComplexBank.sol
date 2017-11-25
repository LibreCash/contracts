pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/math/Math.sol";
import "./zeppelin/lifecycle/Pausable.sol";
import "./interfaces/I_LibreToken.sol";
import "./interfaces/I_Oracle.sol";
import "./interfaces/I_Bank.sol";



contract ComplexBank is Pausable,BankI {
    using SafeMath for uint256;
    address tokenAddress;
    LibreTokenI libreToken;
    
    // TODO; Check that all evetns used and delete unused
    event TokensBought(address _beneficiar, uint256 tokensAmount, uint256 cryptoAmount);
    event TokensSold(address _beneficiar, uint256 tokensAmount, uint256 cryptoAmount);
    event UINTLog(string description, uint256 data);
    event BuyOrderCreated(uint256 amount);
    event SellOrderCreated(uint256 amount);
    event LogBuy(address clientAddress, uint256 tokenAmount, uint256 cryptoAmount, uint256 buyPrice);
    event LogSell(address clientAddress, uint256 tokenAmount, uint256 cryptoAmount, uint256 sellPrice);
    event OrderQueueGeneral(string description);
    event RateBuyLimitOverflow(uint256 cryptoFiatRateBuy, uint256 maxRate, uint256 cryptoAmount);
    event RateSellLimitOverflow(uint256 cryptoFiatRateSell, uint256 maxRate, uint256 tokenAmount);
    event CouldntCancelOrder(bool ifBuy, uint256 orderID);
    event SendEtherError(string error, address _addr);
    
    uint256 constant MIN_ENABLED_ORACLES = 0; //2;
    uint256 constant MIN_READY_ORACLES = 1; //2;
    uint256 constant COUNT_EVENT_ORACLES = MIN_READY_ORACLES + 1;
    uint256 constant MIN_RELEVANCE_PERIOD = 1 minutes;
    uint256 constant MAX_RELEVANCE_PERIOD = 48 hours;
    // отводим 20 минут для calcRates() после requestUpdateRates()
    uint256 constant MAX_CALCRATES_PERIOD = 20 minutes;
    // отводим час на разбор очередей после requestUpdateRates(), MAX_CALCRATES_PERIOD включён сюда
    uint256 constant MAX_PROCESSQUEUES_PERIOD = 60 minutes;

    uint256 constant REVERSE_PERCENT = 100;
    uint256 constant RATE_MULTIPLIER = 1000; // doubling in oracleBase __callback as parseIntRound(..., 3) as 3
    uint256 constant MAX_MINIMUM_BUY = 100 ether;
    uint256 constant MIN_MAXIMUM_BUY = 100 ether;
    uint256 constant MAX_MINIMUM_TOKENS_SELL = 400 * 100 * 10**18; // 100 ether * 400 usd/eth
    uint256 constant MIN_MAXIMUM_TOKENS_SELL = 400 * 100 * 10**18; // 100 ether * 400 usd/eth

    uint256 public relevancePeriod = 23 hours; // Минимальное время между calcRates() прошлого раунда
                                               // и requestUpdateRates() следующего

    uint256 public timeUpdateRequest = 0; // the time of requestUpdateRates()
    uint256 public timeCalcRates = 0; // the time of emission round (when calcRates() done)

    function timeSinceUpdateRequest() public view returns (uint256) {return now - timeUpdateRequest; }
    function timeSinceCalcRates() public view returns (uint256) {return now - timeCalcRates; }

    struct Limit {
        uint256 min;
        uint256 max;
    }

    // Limits start
    Limit public buyLimit = Limit(0, 99999 * 1 ether);
    Limit public sellLimit = Limit(0, 99999 * 1 ether);
    // Limits end

    modifier afterRelevancePeriod() {
        // с последнего запуска calcRates() должно пройти relevancePeriod или больше
        // напомню, calcRates() запускается не позже, чем MAX_CALCRATES_PERIOD (20 мин.) от requestUpdateRates()
        require(now >= timeCalcRates + relevancePeriod);
        _;
    }

    modifier calcRatesAllowed() {
        // с последнего запуска updateRates() не должно пройти больше чем MAX_CALCRATES_PERIOD (20 мин.)
        require(now <= timeUpdateRequest + MAX_CALCRATES_PERIOD);
        _;
    }

    modifier processingQueuesAllowed() {
        // курс актуален для разбора очередей
        // когда: когда с момента requestUpdateRates() не успело пройти MAX_PROCESSQUEUES_PERIOD (1 час)
        require(
            (now <= timeUpdateRequest + MAX_PROCESSQUEUES_PERIOD) &&
            (cryptoFiatRateBuy != 0) &&
            (cryptoFiatRateSell != 0)
        );
        require(timeUpdateRequest < timeCalcRates); // должен быть посчитан курс, а не просто запрошены данные
        _;
    }

    modifier processingQueuesNotAllowed() {
        // время, когда обработка очередей запрещена
        // используется для разрешения создания ордеров в любое время кроме времени обработки очереди
        // время обр. очереди это когда с момента requestUpdateRates() не успело пройти MAX_PROCESSQUEUES_PERIOD (1 час)
        require(now > timeUpdateRequest + MAX_PROCESSQUEUES_PERIOD);
        // даже если курс не посчитан пока что, то всё равно на паузе будет. С момента запроса данных у оракулов
        _;
    }

    /**
     * @dev Constructor.
     */
    function ComplexBank() {
        // Do something 
    }

    // 01-emission start

    /**
     * @dev Creates buy order.
     * @param _address Beneficiar.
     * @param _rateLimit Max affordable buying rate, 0 to allow all.
     */
    function createBuyOrder(address _address, uint256 _rateLimit) payable public whenNotPaused processingQueuesNotAllowed {
        require((msg.value > buyLimit.min) && (msg.value < buyLimit.max));
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
    }

    /**
     * @dev Creates buy order.
     * @param _rateLimit Max affordable buying rate, 0 to allow all.
     */
    function createBuyOrder(uint256 _rateLimit) payable public whenNotPaused processingQueuesNotAllowed {
        createBuyOrder(msg.sender, _rateLimit);
    }

    /**
     * @dev Creates sell order.
     * @param _address Beneficiar.
     * @param _tokensCount Amount of tokens to sell.
     * @param _rateLimit Min affordable selling rate, 0 to allow all.
     */
    function createSellOrder(address _address, uint256 _tokensCount, uint256 _rateLimit) public whenNotPaused processingQueuesNotAllowed {
        require((_tokensCount > sellLimit.min) && (_tokensCount < sellLimit.max));
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
    function createSellOrder(uint256 _tokensCount, uint256 _rateLimit) public whenNotPaused processingQueuesNotAllowed {
        createSellOrder(msg.sender, _tokensCount, _rateLimit);
    }

    /**
     * @dev Fallback function.
     */
    function () whenNotPaused processingQueuesNotAllowed payable external {
        createBuyOrder(msg.sender, 0); // 0 - без ценовых ограничений
    }

    /**
     * @dev Sets min buy sum (in Wei).
     * @param _minBuyInWei - min buy sum in Wei.
     */
    function setMinBuyLimit(uint _minBuyInWei) public onlyOwner {
        require(_minBuyInWei <= MAX_MINIMUM_BUY);
        buyLimit.min = _minBuyInWei;
    }

    /**
     * @dev Sets max buy sum (in Wei).
     * @param _maxBuyInWei - max buy sum in Wei.
     */
    function setMaxBuyLimit(uint _maxBuyInWei) public onlyOwner {
        require(_maxBuyInWei >= MIN_MAXIMUM_BUY);
        buyLimit.max = _maxBuyInWei;
    }

    /**
     * @dev Sets min sell tokens amount.
     * @param _minSellLimit - min sell tokens.
     */
    function setMinSellLimit(uint _minSellLimit) public onlyOwner {
        require(_minSellLimit <= MAX_MINIMUM_TOKENS_SELL);
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
    uint256 public buyNextOrder = 0; // Хранит следующий за последним номер ордера
    uint256 public sellNextOrder = 0;

    mapping (address => uint256) balanceEther; // возврат средств

    /**
     * @dev Sends refund.
     */
    function getEther() public {
        if (this.balance < balanceEther[msg.sender]) {
            SendEtherError("У контракта недостаточно средств!", msg.sender);
        } else {
            if (msg.sender.send(balanceEther[msg.sender]))
                balanceEther[msg.sender] = 0;
            else
                SendEtherError("Ошибка при отправке средств!", msg.sender);
        }
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
     */
    function cancelBuyOrder(uint256 _orderID) private returns (bool) {
        if (buyOrders[_orderID].recipientAddress == 0x0)
            return false;

        balanceEther[buyOrders[_orderID].senderAddress] = balanceEther[buyOrders[_orderID].senderAddress].add(buyOrders[_orderID].orderAmount);
        buyOrders[_orderID].recipientAddress = 0x0;

        return true;
    }
    
    /**
     * @dev Cancels sell order.
     * @param _orderID The ID of order.
     */
   function cancelSellOrder(uint256 _orderID) private returns(bool) {
        if (sellOrders[_orderID].recipientAddress == 0x0)
            return false;

        libreToken.mint(sellOrders[_orderID].senderAddress, sellOrders[_orderID].orderAmount);
        sellOrders[_orderID].recipientAddress = 0x0;
        return true;
    }

    /**
     * @dev Fills buy order from queue.
     * @param _orderID The order ID.
     */
    function processBuyOrder(uint256 _orderID) internal returns (bool) {
        if (buyOrders[_orderID].recipientAddress == 0x0)
            return true;

        uint256 cryptoAmount = buyOrders[_orderID].orderAmount;
        uint256 tokensAmount = cryptoAmount.mul(cryptoFiatRateBuy).div(RATE_MULTIPLIER);
        address recipientAddress = buyOrders[_orderID].recipientAddress;
        uint256 maxRate = buyOrders[_orderID].rateLimit;

        if ((maxRate != 0) && (cryptoFiatRateBuy > maxRate)) {
            RateBuyLimitOverflow(cryptoFiatRateBuy, maxRate, cryptoAmount); // TODO: Delete it after tests
            cancelBuyOrder(_orderID);
        } else {
            libreToken.mint(recipientAddress, tokensAmount);
            buyOrders[_orderID].recipientAddress = 0x0;
            LogBuy(recipientAddress, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
        }
        return true;
    }

    /**
     * @dev Fill buy orders queue (alias with no order limit).
     */
    function processBuyQueue() public whenNotPaused processingQueuesAllowed returns (bool) {
        return processBuyQueue(0);
    }

    /**
     * @dev Fill buy orders queue.
     * @param _limit Order limit.
     */
    function processBuyQueue(uint256 _limit) public whenNotPaused processingQueuesAllowed returns (bool) {
        if ((_limit == 0) || ((buyOrderIndex + _limit) > buyNextOrder))
            _limit = buyNextOrder;
        else
            _limit += buyOrderIndex;

        for (uint i = buyOrderIndex; i < _limit; i++) {
            processBuyOrder(i);
        }

        if (_limit == buyNextOrder) {
            buyOrderIndex = 0;
            buyNextOrder = 0;
            OrderQueueGeneral("Очередь ордеров на покупку очищена");
            if (sellNextOrder == 0) {
                timeUpdateRequest = 0;
            }
        } else {
            buyOrderIndex = _limit;
            OrderQueueGeneral("Очередь ордеров на покупку очищена не до конца");
        }
        
        return true;
    }

    /**
     * @dev Fills sell order from queue.
     * @param _orderID The order ID.
     */
    function processSellOrder(uint256 _orderID) internal returns (bool) {
        if (sellOrders[_orderID].recipientAddress == 0x0)
            return true;
        
        address recipientAddress = sellOrders[_orderID].recipientAddress;
        address senderAddress = sellOrders[_orderID].senderAddress;
        uint256 tokensAmount = sellOrders[_orderID].orderAmount;
        uint256 cryptoAmount = tokensAmount.mul(RATE_MULTIPLIER).div(cryptoFiatRateSell);
        uint256 minRate = sellOrders[_orderID].rateLimit;

        if ((minRate != 0) && (cryptoFiatRateSell < minRate)) {
            RateSellLimitOverflow(cryptoFiatRateSell, minRate, cryptoAmount);
            cancelSellOrder(_orderID);
            libreToken.mint(senderAddress, tokensAmount);
        } else {
            balanceEther[senderAddress] = balanceEther[senderAddress].add(cryptoAmount);
            LogSell(recipientAddress, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
        }      
        return true;
    }

    /**
     * @dev Fill sell orders queue.
     * @param _limit Order limit.
     */
    function processSellQueue(uint256 _limit) public whenNotPaused processingQueuesAllowed returns (bool) {
        if ((_limit == 0) || ((sellOrderIndex + _limit) > sellNextOrder)) 
            _limit = sellNextOrder;
        else
            _limit += sellOrderIndex;
                
        // TODO: при нарушении данного условия контракт окажется сломан. Нарушение малореально, но всё же найти выход
        for (uint i = sellOrderIndex; i < _limit; i++) {
            processSellOrder(i);
        }

        if (_limit == sellNextOrder) {
            sellOrderIndex = 0;
            sellNextOrder = 0;
            OrderQueueGeneral("Очередь ордеров на продажу очищена");
            if (buyNextOrder == 0) {
                timeUpdateRequest = 0;
            }
        } else {
            sellOrderIndex = _limit;
            OrderQueueGeneral("Очередь ордеров на продажу очищена не до конца");
        }
        
        return true;
    }
    // 02-queue end


    // admin start
    // C идеологической точки зрения давать такие привилегии админу может быть неправильно
    /**
     * @dev Cancels buy order (by the owner).
     * @param _orderID The order ID.
     */
    function cancelBuyOrderOwner(uint256 _orderID) public onlyOwner {
        if (!cancelBuyOrder(_orderID))
            revert();
    }

    /**
     * @dev Cancels sell order (by the owner).
     * @param _orderID The order ID.
     */
    function cancelSellOrderOwner(uint256 _orderID) public onlyOwner {
        if (!cancelSellOrder(_orderID))
            revert();
    }

    /**
     * @dev Gets buy order (by the owner).
     * @param _orderID The order ID.
     */
    function getBuyOrder(uint256 _orderID) public onlyOwner view returns (address, address, uint256, uint256, uint256) {
        require(buyNextOrder > 0 && buyNextOrder >= _orderID && buyOrderIndex <= _orderID);
        return (buyOrders[_orderID].senderAddress, buyOrders[_orderID].recipientAddress,
                buyOrders[_orderID].orderAmount, buyOrders[_orderID].orderTimestamp,
                buyOrders[_orderID].rateLimit);
    }

    /**
     * @dev Gets sell order (by the owner).
     * @param _orderID The order ID.
     */
    function getSellOrder(uint256 _orderID) public onlyOwner view returns (address, address, uint256, uint256, uint256) {
        require(sellNextOrder > 0 && sellNextOrder >= _orderID && sellOrderIndex <= _orderID);
        return (sellOrders[_orderID].senderAddress, sellOrders[_orderID].recipientAddress,
                sellOrders[_orderID].orderAmount, sellOrders[_orderID].orderTimestamp,
                sellOrders[_orderID].rateLimit);
    }

    /**
     * @dev Gets sell order count (by the owner).
     */
    function getSellOrdersCount() public onlyOwner view returns(uint256) {
        uint256 count = 0;
        for (uint256 i = sellOrderIndex; i < sellNextOrder; i++) {
            if (sellOrders[i].recipientAddress != 0x0) 
                count++;
        }
        return count;
    }

    /**
     * @dev Gets buy order count (by the owner).
     */
    function getBuyOrdersCount() public onlyOwner view returns(uint256) {
        uint256 count = 0;
        for (uint256 i = buyOrderIndex; i < buyNextOrder; i++) {
            if (buyOrders[i].recipientAddress != 0x0) 
                count++;
        }
        return count;
    }

    /**
     * @dev Gets current token address.
     */
    function getToken() public view returns (address) {
        return tokenAddress;
    }
    
    /**
     * @dev Attaches token contract.
     * @param _tokenAddress The token address.
     */
    function attachToken(address _tokenAddress) public onlyOwner {
        tokenAddress = _tokenAddress;
        libreToken = LibreTokenI(tokenAddress);
    }

    // admin end


    // 03-oracles methods start
    event InsufficientOracleData(string description, uint256 oracleCount);
    event OraclizeStatus(address indexed _address, bytes32 oraclesName, string description);
    event OraclesTouched(string description);
    event OracleAdded(address indexed _address, bytes32 name);
    event OracleEnabled(address indexed _address, bytes32 name);
    event OracleDisabled(address indexed _address, bytes32 name);
    event OracleDeleted(address indexed _address, bytes32 name);
    event OracleTouched(address indexed _address, bytes32 name);
    event OracleNotTouched(address indexed _address, bytes32 name);
    event OracleCallback(address indexed _address, bytes32 name, uint256 result);
    event TextLog(string data);
    event OracleReadyNearToMin(uint256 count);

    struct OracleData {
        bytes32 name;
        uint256 rating;
        bool enabled;
        address next;
    }

    mapping (address => OracleData) public oracles;
    uint256 countOracles;
    address public firstOracle = 0x0;
    //address lastOracle = 0x0;

    uint256 public cryptoFiatRateBuy = 1000;
    uint256 public cryptoFiatRateSell = 1000;
    uint256 public cryptoFiatRate;
    uint256 public buyFee = 0;
    uint256 public sellFee = 0;
    uint constant MAX_ORACLE_RATING = 10000;
    uint256 constant MAX_FEE = 7000; // 70%

    Limit buyFeeLimit = Limit(0, MAX_FEE);
    Limit sellFeeLimit = Limit(0, MAX_FEE);

    /**
     * @dev Returns enabled oracles count.
     */
    function numEnabledOracles() public onlyOwner view returns (uint256) {
        uint256 numOracles = 0;

        for (address current = firstOracle; current != 0x0; current = oracles[current].next) {
            if (oracles[current].enabled == true)
                numOracles++;
        }
        
        return numOracles;
    }

    /**
     * @dev Returns ready (which have data to be used) oracles count.
     */
    function numReadyOracles() public onlyOwner view returns (uint256) {
        uint256 numOracles = 0;
        for (address current = firstOracle; current != 0x0; current = oracles[current].next) {
            OracleData memory currentOracleData = oracles[current];
            OracleI currentOracle = OracleI(current);
            if ((currentOracleData.enabled) && (currentOracle.rate() != 0) && (currentOracle.waitQuery() == false)) 
                numOracles++;
        }
        
        return numOracles;
    }

    /**
     * @dev Lets owner to set relevance period.
     * @param _period Period between 5 minutes and 48 hours.
     */
    function setRelevancePeriod(uint256 _period) public onlyOwner {
        require((_period > MIN_RELEVANCE_PERIOD) && (_period < MAX_RELEVANCE_PERIOD));
        relevancePeriod = _period;
    }

    /**
     * @dev Returns oracle count.
     */
    function getOracleCount() public view returns (uint) {
        return countOracles;
    }

    /**
     * @dev Returns whether the oracle exists in the bank.
     * @param _oracle The oracle's address.
     */
    function oracleExists(address _oracle) internal view returns (bool) {
        for (address current = firstOracle; current != 0x0; current = oracles[current].next) {
            if (current == _oracle) 
                return true;
        }
        return false;
    }

    /**
     * @dev Sets buyFee and sellFee.
     * @param _buyFee The buy fee.
     * @param _sellFee The sell fee.
     */
    function setFees(uint256 _buyFee, uint256 _sellFee) public onlyOwner {
        require((_buyFee >= buyFeeLimit.min) && (_buyFee <= buyFeeLimit.max));
        require((_sellFee >= sellFeeLimit.min) && (_sellFee <= sellFeeLimit.max));

        if (sellFee != _sellFee) {
            uint256 maximalOracleRate = cryptoFiatRateSell.mul(RATE_MULTIPLIER).mul(REVERSE_PERCENT).div(RATE_MULTIPLIER * REVERSE_PERCENT + sellFee);
            sellFee = _sellFee;
            cryptoFiatRateSell = maximalOracleRate.mul(RATE_MULTIPLIER * REVERSE_PERCENT + sellFee).div(RATE_MULTIPLIER * REVERSE_PERCENT);
        }
        if (buyFee != _buyFee) {
            uint256 minimalOracleRate = cryptoFiatRateBuy.mul(RATE_MULTIPLIER * REVERSE_PERCENT).div(RATE_MULTIPLIER * REVERSE_PERCENT - buyFee);
            buyFee = _buyFee;
            cryptoFiatRateBuy = minimalOracleRate.mul(RATE_MULTIPLIER * REVERSE_PERCENT - buyFee).div(RATE_MULTIPLIER * REVERSE_PERCENT);
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
        OracleData memory newOracle = OracleData({
            name: oracleName,
            rating: MAX_ORACLE_RATING.div(2),
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
        OracleAdded(_address, oracleName);
    }

    /**
     * @dev Disables an oracle.
     * @param _address The oracle address.
     */
    function disableOracle(address _address) public onlyOwner {
        require((oracleExists(_address)) && (oracles[_address].enabled));
        oracles[_address].enabled = false;
        OracleDisabled(_address, oracles[_address].name);
    }

    /**
     * @dev Enables an oracle.
     * @param _address The oracle address.
     */
    function enableOracle(address _address) public onlyOwner {
        require((oracleExists(_address)) && (!oracles[_address].enabled));
        oracles[_address].enabled = true;
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
            for (; oracles[prev].next != _address; prev = oracles[prev].next) {}
            oracles[prev].next = oracles[_address].next;
        }
        
        delete oracles[_address];
        countOracles--;
    }
    
    /**
     * @dev Gets oracle rating.
     * @param _address The oracle address.
     */
    function getOracleRating(address _address) internal view returns(uint256) {
        return oracles[_address].rating;
    }

    /**
     * @dev Sets oracle rating.
     * @param _address The oracle address.
     * @param _rating Value of rating
     */
    function setOracleRating(address _address, uint256 _rating) internal {
        require((oracleExists(_address)) && (_rating > 0) && (_rating <= MAX_ORACLE_RATING));
        oracles[_address].rating = _rating;
    }

    /**
     * @dev Sends money to oracles.
     * @param _fundToOracle Desired balance of every oracle.
     */
    function fundOracles(uint256 _fundToOracle) public payable onlyOwner {
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (oracles[cur].enabled == false) 
                continue; // Ignore disabled oracles

            if (cur.balance < _fundToOracle) {
               cur.transfer(_fundToOracle.sub(cur.balance));
            }
        }
    }

    /**
     * @dev Requests every enabled oracle to get the actual rate.
     */
    function requestUpdateRates() public afterRelevancePeriod {
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (oracles[cur].enabled) {
                OracleI currentOracle = OracleI(cur);
                if (currentOracle.waitQuery() == false) {
                    bool updateRateReturned = currentOracle.updateRate();
                    if (updateRateReturned)
                        OracleTouched(cur, oracles[cur].name);
                    else
                        OracleNotTouched(cur, oracles[cur].name);
                }
            }
        } // foreach oracles
        timeUpdateRequest = now;
        OraclesTouched("Запущено обновление курсов");
    }

    /**
     * @dev Clears too-long-waiting oracles.
     */
    function processWaitingOracles() internal {
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (oracles[cur].enabled) {
                OracleI currentOracle = OracleI(cur);
                if (currentOracle.waitQuery() != false) {
                    // если оракул ждёт 10 минут и больше
                    if (currentOracle.updateTime() < now - 10 minutes) {
                        currentOracle.clearState(); // но не ждать
                    } else {
                        revert(); // не даём завершить, пока есть ждущие менее 10 минут оракулы
                    }
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
        processWaitingOracles(); // выкинет если есть оракулы, ждущие менее 10 минут
        checkContract();
        uint256 minimalRate = 2**256 - 1; // Max for UINT256
        uint256 maximalRate = 0;
        
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            OracleData memory currentOracleData = oracles[cur];
            OracleI currentOracle = OracleI(cur);
            uint256 _rate = currentOracle.rate();
            if ((currentOracleData.enabled) && (currentOracle.waitQuery() == false) && (_rate != 0)) {
                minimalRate = Math.min256(_rate, minimalRate);    
                maximalRate = Math.max256(_rate, maximalRate);
           }
        } // foreach oracles

        uint256 middleRate = minimalRate.add(maximalRate).div(2);
        cryptoFiatRateBuy = minimalRate.sub(minimalRate.mul(buyFee).div(REVERSE_PERCENT).div(RATE_MULTIPLIER));
        cryptoFiatRateSell = maximalRate.add(maximalRate.mul(sellFee).div(REVERSE_PERCENT).div(RATE_MULTIPLIER));
        cryptoFiatRate = middleRate;
        timeCalcRates = now;
    }
    // 04-spread calc end

    // 05-monitoring start
    uint256 constant TARGET_VIOLANCE_ALERT = 20000; // 200% Проценты при котором происходит уведомление
    uint256 constant STOCK_VIOLANCE_ALERT = 3000; // 30% процент разницы между биржами при котором происходит уведомление

    /**
     * @dev Checks the contract state.
     */
    function checkContract() public {
        // TODO: Добавить проверки
        uint256 countOracles = numReadyOracles();
        require (countOracles >= MIN_READY_ORACLES);
        if (countOracles < COUNT_EVENT_ORACLES) {
            OracleReadyNearToMin(countOracles);
        }
    }   

    // TODO: change to internal after tests
    /**
     * @dev Gets target rate violence.
     * @param _newCryptoFiatRate New rate.
     */
    function targetRateViolance(uint256 _newCryptoFiatRate) public view returns(uint256) {
        uint256 maxRate = Math.max256(cryptoFiatRate, _newCryptoFiatRate);
        uint256 minRate = Math.min256(cryptoFiatRate, _newCryptoFiatRate);
        return percent(maxRate, minRate, 2);
    }
    // 05-monitoring end
    
    // 08-helper methods start
    
    /**
     * @dev Calculate percents using fixed-float arithmetic.
     * @param _numerator - Calculation numerator (first number)
     * @param _denominator - Calculation denomirator (first number)
     * @param _precision - calc precision
     */
    function percent(uint _numerator, uint _denominator, uint _precision) internal constant returns(uint) {
        uint numerator = _numerator.mul(10 ** (_precision + 1));
        uint quotient = numerator.div(_denominator).add(5).div(10);
        return quotient;
    }

    // 08-helper methods end



    // sytem methods start

    /**
     * @dev Returns total tokens count.
     */
    function totalTokenCount() public view returns (uint256) {
        return libreToken.getTokensAmount();
    }

    /**
     * @dev Returns total tokens price in Wei.
     */
    function totalTokensPrice() public view returns (uint256) {
        return totalTokenCount().mul(cryptoFiatRateSell);
    }

    // TODO: удалить после тестов, нужен чтобы возвращать эфир с контракта
    /**
     * @dev Withdraws all the balance.
     */
    function withdrawBalance() public onlyOwner {
        owner.transfer(this.balance);
    }
    // system methods end
}