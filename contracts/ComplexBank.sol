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
        if (buyOrderLast == buyOrders.length) {
            buyOrders.length += 1;
        }
        buyOrders[buyOrderLast++] = OrderData({
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
        if (sellOrderLast == sellOrders.length) {
            sellOrders.length += 1;
        }
        sellOrders[sellOrderLast++] = OrderData({
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

    // TODO: Убрать public после тестов. Необходимо для отображения ордеров.
    OrderData[] public buyOrders; // очередь ордеров на покупку
    OrderData[] public sellOrders; // очередь ордеров на покупку
    uint256 buyOrderIndex = 0; // Хранит последний обработанный ордер
    uint256 sellOrderIndex = 0;// Хранит последний обработанный ордер
    uint256 buyOrderLast = 0;
    uint256 sellOrderLast = 0;

   function cancelBuyOrder(uint256 _orderID) private returns (bool) {
        if (buyOrders[_orderID].recipientAddress != 0x0) 
            return false;
        bool sent = buyOrders[_orderID].recipientAddress.send(buyOrders[_orderID].orderAmount);
        if (sent) {
            buyOrders[_orderID].recipientAddress = 0x0;
        } else {
            return false;
        }
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
            if (!cancelBuyOrder(_orderID)) {
                CouldntCancelOrder(true, _orderID);
            }
            return true; // go next orders
        }
        libreToken.mint(recipientAddress, tokensAmount);
        LogBuy(recipientAddress, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
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
        require(cryptoFiatRateBuy != 0); // возможно еще надо добавить && libreToken != address(0x0) 

        if (_limit == 0 || _limit > buyOrderLast)
            _limit = buyOrderLast;
        
        for (uint i = buyOrderIndex; i < _limit; i++) {
                // Если попали на удаленный\несуществующий ордер - переходим к следующему
                if (!processBuyOrder(i)) { // TODO: внутри processBuyOrder нет ни одной ветки которая приводит к этому условию
                    buyOrderIndex = i;
                    OrderQueueGeneral("Очередь ордеров на покупку очищена не до конца");
                    return false;
                }
            delete(buyOrders[i]); // в solidity массив не сдвигается, тут будет нулевой элемент
        } // for

        // дешёвая "очистка" массива
        buyOrderIndex = 0;
        buyOrderLast = 0;
        OrderQueueGeneral("Очередь ордеров на покупку очищена");
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
            if (!cancelSellOrder(_orderID)) {
                CouldntCancelOrder(false, _orderID); // TODO: Maybe delete after tests
            }
            return true; // go next orders
        }
        if (this.balance < cryptoAmount) {  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(cryptoFiatRateSell).div(100);
            // слкдующую строчку продумать
            // dn: Тщательно перепроверить на логические и прочие ошибки, иначе нас могут ограбить
            libreToken.mint(senderAddress, sellOrders[_orderID].orderAmount.sub(tokensAmount)); // TODO: Проверить не может ли здесь быть исключения
            cryptoAmount = this.balance;
        } else {
            tokensAmount = sellOrders[_orderID].orderAmount;
            cryptoAmount = tokensAmount.mul(100).div(cryptoFiatRateSell);
        }
        // dn: тщательно перепроверить эту строчку
        if (!recipientAddress.send(cryptoAmount)) { 
            libreToken.mint(senderAddress, tokensAmount); // so as burned at sellTokens
            return true;                                         
        } 
        LogSell(recipientAddress, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
        return true;
    }

    /**
     * @dev Fill sell orders queue.
     */
    function processSellQueue(uint256 _limit) public whenNotPaused returns (bool) {
        require(cryptoFiatRateSell != 0);

        if (_limit == 0 || _limit > sellOrderLast) 
            _limit = sellOrderLast;
                
        // TODO: при нарушении данного условия контракт окажется сломан. Нарушение малореально, но всё же найти выход
        for (uint i = sellOrderIndex; i < _limit; i++) {
            if (!processSellOrder(i)) { // TODO: Удалить, нет веток которые возвращают false
                sellOrderIndex = i;
                OrderQueueGeneral("Очередь ордеров на продажу очищена не до конца");
                return false;
            } 
            delete(sellOrders[i]); // в solidity массив не сдвигается, тут будет нулевой элемент
        } // for
        // дешёвая "очистка" массива
        sellOrderIndex = 0;
        sellOrderLast = 0;
        OrderQueueGeneral("Очередь ордеров на продажу очищена");
        return true;
    }
    // 02-queue end


    // admin start
    // C идеологической точки зрения давать такие привилегии админу может быть неправильно
    function cancelBuyOrderAdm(uint256 _orderID) public onlyOwner {
        cancelBuyOrder(_orderID);
    }

    function cancelSellOrderAdm(uint256 _orderID) public onlyOwner {
        cancelSellOrder(_orderID);
    }

    function getBuyOrder(uint256 i) public onlyOwner view returns (address, address, uint256, uint256, uint256) {
        require(buyOrderLast > 0 && buyOrderLast >= i && buyOrderIndex <= i);
        return (buyOrders[i].senderAddress, buyOrders[i].recipientAddress,
                buyOrders[i].orderAmount, buyOrders[i].orderTimestamp,
                buyOrders[i].rateLimit);
    }

    function getSellOrder(uint256 i) public onlyOwner view returns (address, address, uint256, uint256, uint256) {
        require(sellOrderLast > 0 && sellOrderLast >= i && sellOrderIndex <= i);
        return (sellOrders[i].senderAddress, sellOrders[i].recipientAddress,
                sellOrders[i].orderAmount, sellOrders[i].orderTimestamp,
                sellOrders[i].rateLimit);
    }

    function getSellOrdersCount() public onlyOwner view returns(uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < sellOrders.length; i++) {
            if (sellOrders[i].recipientAddress != 0x0) 
                count++;
        }
        return count;
    }

    function getBuyOrdersCount() public onlyOwner view returns(uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < buyOrders.length; i++) {
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
        libreToken.setBankAddress(address(this));
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
    event OracleCallback(address indexed _address, bytes32 name, uint256 result);
    event TextLog(string data);

    uint256 constant MIN_ENABLED_ORACLES = 0; //2;
    uint256 constant MIN_WAITING_ORACLES = 2; //количество оракулов, которое допустимо омтавлять в ожидании
    uint256 constant MIN_READY_ORACLES = 1; //2;
    uint256 constant RELEVANCE_PERIOD = 24 hours; // Время актуальности курса

    struct OracleData {
        bytes32 name;
        uint256 rating;
        bool enabled;
        bytes32 queryId;
        uint256 updateTime; // time of callback
        uint256 cryptoFiatRate; // exchange rate
        address next; // логичнее было сделать отдельную структуру, но для экономии пусть будет так!
    }

    mapping (address => OracleData) oracles;
    uint256 countOracles;
    address firstOracle = 0x0;
    //address lastOracle = 0x0;

    uint256 public cryptoFiatRateBuy;
    uint256 public cryptoFiatRateSell;
    uint256 public cryptoFiatRate;
    uint256 public buyFee = 0;
    uint256 public sellFee = 0;
    uint256 timeUpdateRequest = 0;
    uint constant MAX_ORACLE_RATING = 10000;
    

    // TODO: Change visiblity after tests
    function numWaitingOracles() public view returns (uint256) {
        uint256 numOracles = 0;

        for (address current = firstOracle; current != 0x0; current = oracles[current].next) {
            if (oracles[current].queryId != 0x0)
                numOracles++;
        }
        
        return numOracles;
    }

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
            if ((currentOracleData.enabled) && (currentOracleData.cryptoFiatRate != 0) && (currentOracleData.queryId == 0x0)) 
                numOracles++;
        }
        
        return numOracles;
    }

    function getOracleCount() public view returns (uint) {
        return countOracles;
    }

    function isOracle(address _oracle) internal returns (bool) {
        if (oracles[_oracle].name != 0) return true;
        else return false;
    }
    
    /**
     * @dev Adds an oracle.
     * @param _address The oracle address.
     */
    function addOracle(address _address) public onlyOwner {
        require((_address != 0x0) && (!isOracle(_address)));
        OracleI currentOracle = OracleI(_address);
        
        currentOracle.setBank(address(this));
        bytes32 oracleName = currentOracle.getName();
        OracleData memory newOracle = OracleData({
            name: oracleName,
            rating: MAX_ORACLE_RATING.div(2),
            enabled: true,
            queryId: 0x0,
            updateTime: 0,
            cryptoFiatRate: 0,
            next: 0x0
        });

        oracles[_address] = newOracle;
        if (firstOracle == 0x0) firstOracle = _address;
        else {
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
        require((isOracle(_address)) && (oracles[_address].enabled));
        oracles[_address].enabled = false;
        OracleDisabled(_address, oracles[_address].name);
    }

    /**
     * @dev Enable oracle.
     * @param _address The oracle address.
     */
    function enableOracle(address _address) public onlyOwner {
        require((isOracle(_address)) && (!oracles[_address].enabled));
        oracles[_address].enabled = true;
        OracleEnabled(_address, oracles[_address].name);
    }

    /**
     * @dev Delete oracle.
     * @param _address The oracle address.
     */
    function deleteOracle(address _address) public onlyOwner {
        require(isOracle(_address));
        OracleDeleted(_address, oracles[_address].name);
        if (firstOracle == _address) firstOracle = oracles[_address].next;
        else {
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
        require((isOracle(_address)) && (_rating > 0) && (_rating <= MAX_ORACLE_RATING));
        oracles[_address].rating = _rating;
    }

    /**
     * @dev Gets oracle crypto-fiat rate.
     * @param _address The oracle address.
     */
    function getOracleRate(address _address) internal view returns(uint256) {
        return oracles[_address].cryptoFiatRate;
    }

    function fundOracles(uint256 fundToOracle) public payable onlyOwner {
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (oracles[cur].enabled == false) 
                continue; // Ignore disabled oracles

            if (cur.balance < fundToOracle) {
               cur.transfer(fundToOracle - cur.balance);
            }
        }
    }

    // TODO: change to intrernal or add onlyOwner
    function requestUpdateRates() public {
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if ((oracles[cur].enabled) && (oracles[cur].queryId == 0x0)) {
                bytes32 queryId = OracleI(cur).updateRate();
                OracleTouched(cur, oracles[cur].name);
                oracles[cur].queryId = queryId;
            }
            timeUpdateRequest = now;
        } // foreach oracles
        OraclesTouched("Запущено обновление курсов");
    }

    /**
     * @dev The callback from oracles.
     * @param _rate The oracle ETH/USD rate.
     * @param _time Update time sent from oracle.
     */
    function oraclesCallback(uint256 _rate, uint256 _time) public { // дублирование _address и msg.sender
        OracleCallback(msg.sender, oracles[msg.sender].name, _rate);
        require(isOracle(msg.sender));
        if (oracles[msg.sender].queryId == 0x0) {
            TextLog("Oracle not waiting");
        } else {
           oracles[msg.sender].cryptoFiatRate = _rate;
           oracles[msg.sender].updateTime = _time;
           oracles[msg.sender].queryId = 0x0;
        }
    }
    
    // TODO - rewrote method, append to google docs
    // TODO: Прикрутить использование метода. Сейчас не используется
    function processWaitingOracles() public {
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            if (oracles[cur].enabled) {
                if (oracles[cur].queryId == 0x0) {
                    // оракул и так не ждёт
                } else {
                    // если оракул ждёт 10 минут и больше
                    if (oracles[cur].updateTime < now - 10 minutes) {
                        oracles[cur].cryptoFiatRate = 0; // быть неактуальным
                        oracles[cur].queryId = 0x0; // но не ждать
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
        uint256 waitingOracles = numWaitingOracles();
        require (waitingOracles <= MIN_WAITING_ORACLES);
        require (numReadyOracles() >= MIN_READY_ORACLES);
        uint256 minimalRate = 2**256 - 1; // Max for UINT256
        uint256 maximalRate = 0;
        
        for (address cur = firstOracle; cur != 0x0; cur = oracles[cur].next) {
            OracleData memory currentOracleData = oracles[cur];
            // TODO: данные хранятся и в оракуле и в эмиссионном контракте
            if ((currentOracleData.enabled) && (currentOracleData.queryId == 0x0) && (currentOracleData.cryptoFiatRate != 0)) {
                minimalRate = Math.min256(currentOracleData.cryptoFiatRate, minimalRate);    
                maximalRate = Math.max256(currentOracleData.cryptoFiatRate, maximalRate);
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