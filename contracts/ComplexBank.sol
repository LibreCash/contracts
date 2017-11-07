pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/math/Math.sol";
import "./zeppelin/lifecycle/Pausable.sol";

interface token {
    function balanceOf(address _owner) public returns (uint256);
    function mint(address _to, uint256 _amount) public;
    function getTokensAmount() public returns(uint256);
    function burn(address _burner, uint256 _value) public;
    function setBankAddress(address _bankAddress) public;
}

interface oracleInterface {
    function updateRate() payable public returns (bytes32);
    function getName() constant public returns (bytes32);
    function setBank(address _bankAddress) public;
    function hasReceivedRate() public returns (bool);
}


contract ComplexBank is Pausable {
    using SafeMath for uint256;
    address tokenAddress;
    token libreToken;
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
    event RateSellLimitOverflow(uint256 cryptoFiatRateBuy, uint256 maxRate, uint256 tokenAmount);
    event CouldntCancelOrder(bool ifBuy, uint256 orderID);
    
    struct Limit {
        uint256 min;
        uint256 max;
    }

    // Limits start
    Limit public buyEther = Limit(0,99999 * 1 ether);
    Limit public sellTokens = Limit(0,99999 * 1 ether);
    // Limits end

    function ComplexBank() {
        // Do something 
    }

    // 01-emission start
    function createBuyOrder(address beneficiary,uint256 rateLimit) public whenNotPaused payable {
        require((msg.value > buyEther.min) && (msg.value < buyEther.max));
        OrderData memory currentOrder = OrderData({
            senderAddress:msg.sender,
            recipientAddress: beneficiary, 
            orderAmount: msg.value, 
            orderTimestamp: now, 
            rateLimit: rateLimit
        });
        addOrderToQueue(orderType.buy,currentOrder);
    }

    function createSellOrder(uint256 _tokensCount, uint256 _rateLimit) whenNotPaused public {
    require((_tokensCount > sellTokens.min) && (_tokensCount < sellTokens.max));
    require(_tokensCount <= libreToken.balanceOf(msg.sender));
    OrderData memory currentOrder  = OrderData({
        senderAddress:msg.sender,
        recipientAddress: msg.sender, 
        orderAmount: _tokensCount, 
        orderTimestamp: now, 
        rateLimit: _rateLimit
    });
    addOrderToQueue(orderType.sell,currentOrder);
    libreToken.burn(msg.sender, _tokensCount);
    SellOrderCreated(_tokensCount); // TODO: maybe add beneficiary?
    }

    function () whenNotPaused payable external {
        createBuyOrder(msg.sender, 0); // 0 - без ценовых ограничений
    }
    // 01-emission end

    // 02-queue start
    enum orderType { buy, sell}
    struct OrderData {
        address senderAddress;
        address recipientAddress;
        uint256 orderAmount;
        uint256 orderTimestamp;
        uint256 rateLimit;
    }


    OrderData[] buyOrders; // очередь ордеров на покупку
    OrderData[] sellOrders; // очередь ордеров на покупку
    uint256 buyOrderIndex = 0; // Хранит последний обработанный ордер
    uint256 sellOrderIndex = 0;// Хранит последний обработанный ордер

    function addOrderToQueue(orderType typeOrder, OrderData order) internal {
        if (typeOrder == orderType.buy) {
            buyOrders.push(order);
        } else {
            sellOrders.push(order);
        }
    }
   // Используется внутри в случае если не срабатывают условия ордеров 

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
        if (buyOrders[_orderID].senderAddress == 0x0) {
            return true; // ордер удалён, идём дальше
        }

        uint256 cryptoAmount = buyOrders[_orderID].orderAmount;
        uint256 tokensAmount = cryptoAmount.mul(cryptoFiatRateBuy).div(100);
        address recipientAddress = buyOrders[_orderID].recipientAddress;
        uint256 maxRate = buyOrders[_orderID].rateLimit;

        if ((maxRate != 0) && (cryptoFiatRateBuy < maxRate)) {
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

    function processBuyQueue(uint256 limit) public whenNotPaused returns (bool) {
        if(limit == 0) 
            limit = buyOrders.length;
        // TODO: при нарушении данного условия контракт окажется сломан. Нарушение малореально, но всё же найти выход
        for (uint i = buyOrderIndex; i < buyOrders.length; i++) {
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
        OrderQueueGeneral("Очередь ордеров на покупку очищена");
        return true;
    }

    /**
     * @dev Fills sell order from queue.
     * @param _orderID The order ID.
     */
    function processSellOrder(uint256 _orderID) internal returns (bool) {
        if (sellOrders[_orderID].senderAddress == 0x0) {
            return true; // ордер удалён, можно продолжать разгребать
        }
        
        address recipientAddress = sellOrders[_orderID].recipientAddress;
        address senderAddress = sellOrders[_orderID].senderAddress;
        uint256 tokensAmount = sellOrders[_orderID].orderAmount;
        uint256 cryptoAmount = tokensAmount.div(cryptoFiatRateSell).mul(100);
        uint256 minRate = sellOrders[_orderID].rateLimit;

        if ((minRate != 0) && (cryptoFiatRateSell > minRate)) {
            RateBuyLimitOverflow(cryptoFiatRateBuy, minRate, cryptoAmount);
            if (!cancelSellOrder(_orderID)) {
                CouldntCancelOrder(false, _orderID); // TODO: Maybe delete after tests
            }
            return true; // go next orders
        }
        if (this.balance < cryptoAmount) {  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(cryptoFiatRateBuy).div(100);
            // слкдующую строчку продумать
            // dn: Тщательно перепроверить на логические и прочие ошибки, иначе нас могут ограбить
            libreToken.mint(senderAddress, sellOrders[_orderID].orderAmount.sub(tokensAmount)); // TODO: Проверить не может ли здесь быть исключения
            cryptoAmount = this.balance;
        } else {
            tokensAmount = sellOrders[_orderID].orderAmount;
            cryptoAmount = tokensAmount.div(cryptoFiatRateSell).mul(100);
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
    function processSellQueue(uint256 limit) public whenNotPaused returns (bool) {
        if (limit == 0) 
            limit = sellOrders.length;
        // TODO: при нарушении данного условия контракт окажется сломан. Нарушение малореально, но всё же найти выход
        for (uint i = sellOrderIndex; i < limit; i++) {
            if (!processSellOrder(i)) { // TODO: Удалить, нет веток которые возвращают false
                sellOrderIndex = i;
                OrderQueueGeneral("Очередь ордеров на продажу очищена не до конца");
                return false;
            } 
            delete(sellOrders[i]); // в solidity массив не сдвигается, тут будет нулевой элемент
        } // for
        // дешёвая "очистка" массива
        sellOrderIndex = 0;
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

    function getBuyOrders(uint number) public onlyOwner view returns (OrderData) {
        return buyOrders[number];
    }

    function getSellOrders(uint number) public onlyOwner view returns (OrderData[]) {
        return sellOrders[number];
    }

    function getSellOrdersCount() public onlyOwner view returns(uint256) {
        uint256 count = 0;
        for(uint i = 0; i < sellOrders.length; i++) {
            if(sellOrders[i].recipientAddress != 0x0) 
                count++;
        }
        return count;
    }

    function getBuyOrdersCount() public onlyOwner view returns(uint256) {
        uint256 count = 0;
        for(uint i = 0; i < buyOrders.length; i++) {
            if(buyOrders[i].recipientAddress != 0x0) 
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
        libreToken = token(tokenAddress);
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
    uint256 constant MIN_ENABLED_NOT_WAITING_ORACLES = 1; //2;
    uint256 constant RELEVANCE_PERIOD = 24 hours; // Время актуальности курса

    struct OracleData {
        bytes32 name;
        uint256 rating;
        bool enabled;
        bytes32 queryId;
        uint256 updateTime; // time of callback
        uint256 cryptoFiatRate; // exchange rate
        uint listPointer; // чтобы знать по какому индексу удалять из массива oracleAddresses
    }

    mapping (address=>OracleData) oracles;
    address[] oracleAddresses;
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
        for(uint i = 0; i < oracleAddresses.length; i++) {
            if ( oracles[oracleAddresses[i]].queryId != 0x0  ) 
                numOracles++;
        }
        return numOracles;
    }

    function numEnabledOracles() view returns (uint256) {
        uint256 numOracles = 0;
        for(uint i = 0; i < oracleAddresses.length; i++) {
            if ( oracles[oracleAddresses[i]].enabled == true ) 
                numOracles++;
        }
        return numOracles;
    }


    function getOracleCount() public view returns (uint) {
        return oracleAddresses.length;
    }

    function isOracle(address _oracle) internal returns (bool) {
        for (uint i = 0; i < oracleAddresses.length; i++) {
            if ( oracleAddresses[i] == _oracle ) 
                return true;
        }
        return false;
        // TODO: rewrote to use mapping() instead cycle
    }
    
    /**
     * @dev Adds an oracle.
     * @param _address The oracle address.
     */
    function addOracle(address _address) public onlyOwner {
        require(_address != 0x0 && !isOracle (_address));
        oracleInterface currentOracle = oracleInterface(_address);
        
        currentOracle.setBank(address(this));
        bytes32 oracleName = currentOracle.getName();
        OracleData memory newOracle = OracleData({
            name: oracleName, 
            rating: MAX_ORACLE_RATING.div(2), 
            enabled: true, 
            queryId: 0, 
            updateTime: 0, 
            cryptoFiatRate: 0, 
            listPointer: 0
        });
        oracles[_address] = newOracle;
        oracleAddresses.push(_address);
        OracleAdded(_address, oracleName);
    }

    /**
     * @dev Disable oracle.
     * @param _address The oracle address.
     */
    function disableOracle(address _address) public onlyOwner {
        require(isOracle(_address) && oracles[_address].enabled == true);
        oracles[_address].enabled = false;
        OracleDisabled(_address, oracles[_address].name);
    }

    /**
     * @dev Enable oracle.
     * @param _address The oracle address.
     */
    function enableOracle(address _address) public onlyOwner {
        require(isOracle(_address) && oracles[_address].enabled == false);
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
        delete oracles[_address];
        for(uint i = 0; i < oracleAddresses.length; i++) {
            if (oracleAddresses[i] == _address) {
                delete oracleAddresses[i];
                break;
            }
        } // TODO: rewrote without cycle
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
        require(isOracle(_address) && _rating > 0 && _rating <= MAX_ORACLE_RATING);
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
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].enabled == false) 
                continue; // Ignore disabled oracles

            if (oracleAddresses[i].balance < fundToOracle) {
               oracleAddresses[i].transfer(fundToOracle - oracleAddresses[i].balance);
            }
        } // foreach oracles
    }

    // TODO: change to intrernal or add onlyOwner
    function requestUpdateRates() public {
        for (uint i = 0; i < oracleAddresses.length; i++) {
            if ((oracles[oracleAddresses[i]].enabled) && (oracles[oracleAddresses[i]].queryId == bytes32(""))) {
                bytes32 queryId = oracleInterface(oracleAddresses[i]).updateRate();
                OracleTouched(oracleAddresses[i], oracles[oracleAddresses[i]].name);
                oracles[oracleAddresses[i]].queryId = queryId;
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
        if (oracles[msg.sender].queryId == bytes32("")) {
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
        for (uint i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].enabled) {
                if (oracles[oracleAddresses[i]].queryId == bytes32("")) {
                    // оракул и так не ждёт
                } else {
                    // если оракул ждёт 10 минут и больше
                    if (oracles[oracleAddresses[i]].updateTime < now - 10 minutes) {
                        oracles[oracleAddresses[i]].cryptoFiatRate = 0; // быть неактуальным
                        oracles[oracleAddresses[i]].queryId = bytes32(""); // но не ждать
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
        UINTLog("оракулов ждёт", waitingOracles);
        require (numEnabledOracles() - waitingOracles >= MIN_ENABLED_NOT_WAITING_ORACLES);
        UINTLog("вкл. оракулов не ждёт", waitingOracles);
        uint256 numReadyOracles = 0;
        uint256 minimalRate = 2**256 - 1; // Max for UINT256
        uint256 maximalRate = 0;
        
        for (uint i = 0; i < oracleAddresses.length; i++) {
            OracleData memory currentOracle = oracles[oracleAddresses[i]];
            if((currentOracle.cryptoFiatRate == 0)) 
                continue;
            // TODO: данные хранятся и в оракуле и в эмиссионном контракте
            if ((currentOracle.enabled) && (currentOracle.queryId == bytes32(""))) {
                minimalRate = Math.min256(currentOracle.cryptoFiatRate,minimalRate);    
                maximalRate = Math.max256(currentOracle.cryptoFiatRate,maximalRate);
                numReadyOracles++; // TODO: Delete It
            }
        } // foreach oracles

        require (numReadyOracles >= MIN_READY_ORACLES);
        UINTLog("оракулов готово", numReadyOracles);
        uint256 middleRate = minimalRate.add(maximalRate).div(2);
        cryptoFiatRateBuy = minimalRate.sub(minimalRate.mul(buyFee).div(100).div(100));
        cryptoFiatRateSell = maximalRate.add(maximalRate.mul(sellFee).div(100).div(100));
        cryptoFiatRate = middleRate;
    }
    // 04-spread calc end

    // 05-monitoring start
    uint256 constant TARGET_VIOLANCE_ALERT = 20000; // 200% Проценты при котором происходит уведомление
    uint256 constant STOCK_VIOLANCE_ALERT = 3000; // 30% процент разницы между биржами при котором происходит уведомление
    function checkContract() {
        // TODO: Добавить проверки
    }   
    // TODO: change to internal after tests
    function targetRateViolance(uint256 newCryptoFiatRate) public view returns(uint256) {
        uint256 maxRate = Math.max256(cryptoFiatRate,newCryptoFiatRate);
        uint256 minRate = Math.min256(cryptoFiatRate,newCryptoFiatRate);
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
        uint _numerator  = numerator.mul(10 ** (precision+1));
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