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
    
    struct Limit {
        uint256 min;
        uint256 max;
    }

    // Limits start
    Limit public buyEther = Limit(0, 99999 * 1 ether);
    Limit public sellTokens = Limit(0, 99999 * 1 ether);
    // Limits end

    function ComplexBank() {
        // Do something 
    }

    // 01-emission start

    /**
     * @dev Creates buy order.
     * @param _address Beneficiar.
     * @param _rateLimit Max affordable buying rate, 0 to allow all.
     */
    function createBuyOrder(address _address, uint256 _rateLimit) payable public whenNotPaused {
        require((msg.value > buyEther.min) && (msg.value < buyEther.max));
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
    function createBuyOrder(uint256 _rateLimit) payable public {
        createBuyOrder(msg.sender, _rateLimit);
    }

    /**
     * @dev Creates sell order.
     * @param _address Beneficiar.
     * @param _tokensCount Amount of tokens to sell.
     * @param _rateLimit Min affordable selling rate, 0 to allow all.
     */
    function createSellOrder(address _address, uint256 _tokensCount, uint256 _rateLimit) public whenNotPaused {
        require((_tokensCount > sellTokens.min) && (_tokensCount < sellTokens.max));
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
    function createSellOrder(uint256 _tokensCount, uint256 _rateLimit) public {
        createSellOrder(msg.sender, _tokensCount, _rateLimit);
    }

    // TODO: подогнать под текущие функции, возможно их изменить
    // сейчас не использовать
    function addOrderToQueue(orderType typeOrder, OrderData order) internal {
        if (typeOrder == orderType.buy) {
 //           createBuyOrder(order.address, )
            buyOrders.push(order);
        } else {
            sellOrders.push(order);
        }
    }
   // Используется внутри в случае если не срабатывают условия ордеров 

    function () whenNotPaused payable external {
        createBuyOrder(msg.sender, 0); // 0 - без ценовых ограничений
    }

    /**
     * @dev Sets min buy sum (in Wei).
     * @param minBuyInWei - min buy sum in Wei.
     */
    function setMinBuyLimit(uint minBuyInWei) public onlyOwner {
        buyEther.min = minBuyInWei;
    }

    /**
     * @dev Sets max buy sum (in Wei).
     * @param maxBuyInWei - max buy sum in Wei.
     */
    function setMaxBuyLimit(uint maxBuyInWei) public onlyOwner {
        buyEther.max = maxBuyInWei;
    }

    /**
     * @dev Sets min sell tokens amount.
     * @param minSellTokens - min sell tokens.
     */
    function setMinSellLimit(uint minSellTokens) public onlyOwner {
        sellTokens.min = minSellTokens;
    }
    /**
     * @dev Sets max sell tokens amount.
     * @param maxSellTokens - max sell tokens.
     */
    function setMaxSellLimit(uint maxSellTokens) public onlyOwner {
        sellTokens.max = maxSellTokens;
    }

    // 01-emission end

    // 02-queue start
    enum orderType { buy, sell }
    struct OrderData {
        address senderAddress;
        address recipientAddress;
        uint256 orderAmount;
        uint256 orderTimestamp;
        uint256 rateLimit;
    }

    OrderData[] public buyOrders; // очередь ордеров на покупку
    OrderData[] public sellOrders; // очередь ордеров на продажу
    uint256 buyOrderIndex = 0; // Хранит первый номер ордера
    uint256 sellOrderIndex = 0;
    uint256 buyNextOrder = 0; // Хранит следующий за последним номер ордера
    uint256 sellNextOrder = 0;

    mapping (address => uint256) balanceEther; // возврат средств

    function getEther() public {
        require(this.balance >= balanceEther[msg.sender]);
        if (msg.sender.send(balanceEther[msg.sender]))
            balanceEther[msg.sender] = 0;
    }

    function getBalanceEther() constant returns (uint256) {
        return balanceEther[msg.sender];
    }

    function cancelBuyOrder(uint256 _orderID) private returns (bool) {
        if (buyOrders[_orderID].recipientAddress == 0x0)
            return false;

        balanceEther[buyOrders[_orderID].senderAddress] = balanceEther[buyOrders[_orderID].senderAddress].add(buyOrders[_orderID].orderAmount);
        buyOrders[_orderID].recipientAddress = 0x0;

        return true;
    }
    
   // Используется внутри в случае если не срабатывают условия ордеров 
   function cancelSellOrder(uint256 _orderID) private returns(bool) {
        if (sellOrders[_orderID].recipientAddress == 0x0) { 
            return false;
        }

        libreToken.mint(sellOrders[_orderID].senderAddress, sellOrders[_orderID].orderAmount);
        sellOrders[_orderID].recipientAddress = 0x0;
        return true;
    }

    /**
     * @dev Fills buy order from queue.
     * @param _orderID The order ID.
     */
    function processBuyOrder(uint256 _orderID) internal returns (bool) {
        if (buyOrders[_orderID].recipientAddress == 0x0) {
            return true; // ордер удалён, идём дальше
        }

        uint256 cryptoAmount = buyOrders[_orderID].orderAmount;
        uint256 tokensAmount = cryptoAmount.mul(cryptoFiatRateBuy).div(100);
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


    //TODO: добавить обработку очереди по N ордеров
    /**
     * @dev Fill buy orders queue.
     */

    // Алиас для обработки очереди без лимита
    function processBuyQueue() public whenNotPaused returns (bool) {
        return processBuyQueue(0);
    }

    function processBuyQueue(uint256 _limit) public whenNotPaused returns (bool) {
        require(cryptoFiatRateBuy != 0); 

        if (_limit == 0 || (buyOrderIndex + _limit) > buyNextOrder)
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
        if (sellOrders[_orderID].recipientAddress == 0x0) {
            return true; // ордер удалён, можно продолжать разгребать
        }
        
        address recipientAddress = sellOrders[_orderID].recipientAddress;
        address senderAddress = sellOrders[_orderID].senderAddress;
        uint256 tokensAmount = sellOrders[_orderID].orderAmount;
        uint256 cryptoAmount = tokensAmount.mul(100).div(cryptoFiatRateSell);
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
     */
    function processSellQueue(uint256 _limit) public whenNotPaused returns (bool) {
        require(cryptoFiatRateSell != 0);

        if (_limit == 0 || (sellOrderIndex + _limit) > sellNextOrder) 
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
        } else {
            sellOrderIndex = _limit;
            OrderQueueGeneral("Очередь ордеров на продажу очищена не до конца");
        }
        
        return true;
    }
    // 02-queue end


    // admin start
    // C идеологической точки зрения давать такие привилегии админу может быть неправильно
    function cancelBuyOrderAdm(uint256 _orderID) public onlyOwner {
        if (!cancelBuyOrder(_orderID))
            revert();
    }

    function cancelSellOrderAdm(uint256 _orderID) public onlyOwner {
        if (!cancelSellOrder(_orderID))
            revert();
    }

    function getBuyOrder(uint256 i) public onlyOwner view returns (address, address, uint256, uint256, uint256) {
        require(buyNextOrder > 0 && buyNextOrder >= i && buyOrderIndex <= i);
        return (buyOrders[i].senderAddress, buyOrders[i].recipientAddress,
                buyOrders[i].orderAmount, buyOrders[i].orderTimestamp,
                buyOrders[i].rateLimit);
    }

    function getSellOrder(uint256 i) public onlyOwner view returns (address, address, uint256, uint256, uint256) {
        require(sellNextOrder > 0 && sellNextOrder >= i && sellOrderIndex <= i);
        return (sellOrders[i].senderAddress, sellOrders[i].recipientAddress,
                sellOrders[i].orderAmount, sellOrders[i].orderTimestamp,
                sellOrders[i].rateLimit);
    }

    function getSellOrdersCount() public onlyOwner view returns(uint256) {
        uint256 count = 0;
        for (uint256 i = sellOrderIndex; i < sellNextOrder; i++) {
            if (sellOrders[i].recipientAddress != 0x0) 
                count++;
        }
        return count;
    }

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

    uint256 constant MIN_ENABLED_ORACLES = 0; //2;
    uint256 constant MIN_READY_ORACLES = 1; //2;
    uint256 constant COUNT_EVENT_ORACLES = MIN_READY_ORACLES + 1;
    uint256 constant RELEVANCE_PERIOD = 24 hours; // Время актуальности курса

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

    uint256 public cryptoFiatRateBuy = 100;
    uint256 public cryptoFiatRateSell = 100;
    uint256 public cryptoFiatRate;
    uint256 public buyFee = 0;
    uint256 public sellFee = 0;
    uint256 timeUpdateRequest = 0;
    uint constant MAX_ORACLE_RATING = 10000;
    

    // TODO: Change visiblity after tests
    function numEnabledOracles() public view returns (uint256) {
        uint256 numOracles = 0;

        for (address current = firstOracle; current != 0x0; current = oracles[current].next) {
            if (oracles[current].enabled == true)
                numOracles++;
        }
        
        return numOracles;
    }

    function numReadyOracles() public view returns (uint256) {
        uint256 numOracles = 0;
        for (address current = firstOracle; current != 0x0; current = oracles[current].next) {
            OracleData memory currentOracleData = oracles[current];
            OracleI currentOracle = OracleI(current);
            if ((currentOracleData.enabled) && (currentOracle.rate() != 0) && (currentOracle.queryId() == 0x0)) 
                numOracles++;
        }
        
        return numOracles;
    }

    function getOracleCount() public view returns (uint) {
        return countOracles;
    }

    function oracleExists(address _oracle) internal returns (bool) {
        for (address current = firstOracle; current != 0x0; current = oracles[current].next) {
            if (current == _oracle) 
                return true;
        }
        return false;
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
     * @dev Disable oracle.
     * @param _address The oracle address.
     */
    function disableOracle(address _address) public onlyOwner {
        require((oracleExists(_address)) && (oracles[_address].enabled));
        oracles[_address].enabled = false;
        OracleDisabled(_address, oracles[_address].name);
    }

    /**
     * @dev Enable oracle.
     * @param _address The oracle address.
     */
    function enableOracle(address _address) public onlyOwner {
        require((oracleExists(_address)) && (!oracles[_address].enabled));
        oracles[_address].enabled = true;
        OracleEnabled(_address, oracles[_address].name);
    }

    /**
     * @dev Delete oracle.
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
        countOracles --;
    }
    
    /**
     * @dev Gets oracle rating.
     * @param _address The oracle address.
     */
    function getOracleRating(address _address) internal view returns(uint256) {
        return oracles[_address].rating;
    }

    /**
     * @dev Set oracle rating.
     * @param _address The oracle address.
     * @param _rating Value of rating
     */
    function setOracleRating(address _address, uint256 _rating) internal {
        require((oracleExists(_address)) && (_rating > 0) && (_rating <= MAX_ORACLE_RATING));
        oracles[_address].rating = _rating;
    }

    function fundOracles(uint256 fundToOracle) public payable onlyOwner {
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (oracles[cur].enabled == false) 
                continue; // Ignore disabled oracles

            if (cur.balance < fundToOracle) {
               cur.transfer(fundToOracle.sub(cur.balance));
            }
        }
    }

    // TODO: change to intrernal or add onlyOwner
    function requestUpdateRates() public {
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (oracles[cur].enabled) {
                OracleI currentOracle = OracleI(cur);
                if (currentOracle.queryId() == 0x0) {
                    bool updateRateReturned = currentOracle.updateRate();
                    if (updateRateReturned)
                        OracleTouched(cur, oracles[cur].name);
                    else
                        OracleNotTouched(cur, oracles[cur].name);
                }
            }
            timeUpdateRequest = now;
        } // foreach oracles
        OraclesTouched("Запущено обновление курсов");
    }

    // TODO - rewrote method, append to google docs
    // TODO: Прикрутить использование метода. Сейчас не используется
    function processWaitingOracles() internal {
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (oracles[cur].enabled) {
                OracleI currentOracle = OracleI(cur);
                if (currentOracle.queryId() != 0x0) {
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
    function calcRates() public {
        processWaitingOracles(); // выкинет если есть оракулы, ждущие менее 10 минут
        uint256 countOracles = numReadyOracles();
        require (countOracles >= MIN_READY_ORACLES);
        if (countOracles < COUNT_EVENT_ORACLES) {
            OracleReadyNearToMin(countOracles);
        }
        uint256 minimalRate = 2**256 - 1; // Max for UINT256
        uint256 maximalRate = 0;
        
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            OracleData memory currentOracleData = oracles[cur];
            OracleI currentOracle = OracleI(cur);
            uint256 _rate = currentOracle.rate();
            if ((currentOracleData.enabled) && (currentOracle.queryId() == 0x0) && (_rate != 0)) {
                minimalRate = Math.min256(_rate, minimalRate);    
                maximalRate = Math.max256(_rate, maximalRate);
           }
        } // foreach oracles

        uint256 middleRate = minimalRate.add(maximalRate).div(2);
        cryptoFiatRateSell = minimalRate.sub(minimalRate.mul(buyFee).div(100).div(100));
        cryptoFiatRateBuy = maximalRate.add(maximalRate.mul(sellFee).div(100).div(100));
        cryptoFiatRate = middleRate;
    }
    // 04-spread calc end

    // 05-monitoring start
    uint256 constant TARGET_VIOLANCE_ALERT = 20000; // 200% Проценты при котором происходит уведомление
    uint256 constant STOCK_VIOLANCE_ALERT = 3000; // 30% процент разницы между биржами при котором происходит уведомление
    function checkContract() public {
        // TODO: Добавить проверки
    }   
    // TODO: change to internal after tests
    function targetRateViolance(uint256 newCryptoFiatRate) public view returns(uint256) {
        uint256 maxRate = Math.max256(cryptoFiatRate, newCryptoFiatRate);
        uint256 minRate = Math.min256(cryptoFiatRate, newCryptoFiatRate);
        return percent(maxRate,minRate,2);
    }
    // 05-monitoring end
    
    // 08-helper methods start
    
    /**
     * @dev Calculate percents using fixed-float arithmetic.
     * @param numerator - Calculation numerator (first number)
     * @param denominator - Calculation denomirator (first number)
     * @param precision - calc precision
     */
    function percent(uint numerator, uint denominator, uint precision) internal constant returns(uint) {
        uint _numerator = numerator.mul(10 ** (precision+1));
        uint _quotient = _numerator.div(denominator).add(5).div(10);
        return _quotient;
    }

    /**
     * @dev Checks if the rate is up to date
     */
    function isRateActual() public constant returns(bool) {
        return (now <= timeUpdateRequest + RELEVANCE_PERIOD);
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
    function withdrawBalance() public onlyOwner {
        owner.transfer(this.balance);
    }
    // system methods end



}