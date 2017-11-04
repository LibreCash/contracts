pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/lifecycle/Pausable.sol";
import "./UsingMultiOracles.sol";

interface token {
    function balanceOf(address _owner) public returns (uint256);
    function mint(address _to, uint256 _amount) public;
    function getTokensAmount() public returns(uint256);
    function burn(address _burner, uint256 _value) public;
    function setBankAddress(address _bankAddress) public;
}

/**
 * @title BasicBank.
 *
 * @dev Bank contract.
 */
contract BasicBank is UsingMultiOracles, Pausable {
    using SafeMath for uint256;
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

    address tokenAddress;
    token libreToken;

    uint256 timeUpdateRequested;

    uint256 constant MIN_ENABLED_ORACLES = 0; //2;
    uint256 constant MIN_WAITING_ORACLES = 2; //количество оракулов, которое допустимо омтавлять в ожидании
    uint256 constant MIN_READY_ORACLES = 1; //2;
    uint256 constant MIN_ENABLED_NOT_WAITING_ORACLES = 1; //2;

//  /**
//   * @dev Throws if called by any account other than the oracles.
//   */
  /*modifier onlyOracles() {
     for (uint i = 0; i < oracleAddresses.length; i++) {
            require(oracles[oracleAddresses[i]] == msg.sender);
      }
  }*/
    
    struct OrderData {
        address senderAddress;
        address recipientAddress;
        uint256 orderAmount;
        uint256 orderTimestamp;
        uint256 rateLimit;
    }

    OrderData[] buyOrders; // очередь ордеров на покупку
    OrderData[] sellOrders; // очередь ордеров на покупку

    uint256 buyOrderIndex = 0;
    uint256 buyOrderLast = 0;
    uint256 sellOrderIndex = 0;
    uint256 sellOrderLast = 0;

    modifier notPaused() {
        require (!paused);
        _;
    }

    function getBuyOrders() public onlyOwner view returns (OrderData[]) {
        return buyOrders;
    }

    function getSellOrders() public onlyOwner view returns (OrderData[]) {
        return sellOrders;
    }

    function BasicBank() public {
        setBuyTokenLimits(0, MAX_UINT256);
        setSellTokenLimits(0, MAX_UINT256);
     }

     /**
     * @dev Cancels sell order (only owner).
     * @param _orderID The order ID.
     */
    function cancelSellOrderOwner(uint256 _orderID) public onlyOwner {
        cancelSellOrder(_orderID);
    }

     /**
     * @dev Cancels sell order (only owner).
     * @param _orderID The order ID.
     */
    function cancelBuyOrderOwner(uint256 _orderID) public onlyOwner {
        cancelBuyOrder(_orderID);
    }

    /**
     * @dev Cancels buy order without exceptions.
     * @param _orderID The order ID.
     */
    function cancelBuyOrder(uint256 _orderID) internal returns (bool) {
        if (buyOrders[_orderID].senderAddress == 0x0) {
            return false;
        }
        bool sent = buyOrders[_orderID].senderAddress.send(buyOrders[_orderID].orderAmount);
        if (sent) {
            buyOrders[_orderID].senderAddress = 0x0;
            return true;
        }
        return false;
    }

    /**
     * @dev Cancels sell order without exceptions.
     * @param _orderID The order ID.
     */
    function cancelSellOrder(uint256 _orderID) internal returns (bool) {
        if (sellOrders[_orderID].senderAddress == 0x0) {
            return false;
        }
        libreToken.mint(sellOrders[_orderID].senderAddress, sellOrders[_orderID].orderAmount);
        sellOrders[_orderID].senderAddress = 0x0;
        return true;
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

    /**
     * @dev Gets current token address.
     */
    function getToken() public view returns (address) {
        return tokenAddress;
    }

    /**
     * @dev Receives donations.
     */
    function donate() payable public {}

    /**
     * @dev Returns total tokens count.
     */
    function totalTokenCount() public view returns (uint256) {
        return libreToken.getTokensAmount();
    }

    /**
     * @dev Transfers crypto.
     */
    function withdrawCrypto(address _beneficiar) public onlyOwner {
         _beneficiar.transfer(this.balance);
    }

    function () payable external {
        createBuyOrder(msg.sender, 0); // 0 - без ценовых ограничений
    }

    /**
     * @dev Gets token balance of an address.
     * @param _address Address provided.
     */
    function tokenBalanceOf(address _address) public view returns (uint256) {
        return libreToken.balanceOf(_address);
    }

    /**
     * @dev Creates buy order.
     * @param _address Beneficiar.
     * @param _rateLimit Max affordable buying rate, 0 to allow all.
     */
    function createBuyOrder(address _address, uint256 _rateLimit) payable public notPaused {
        require((msg.value > limitBuyOrder.min) && (msg.value < limitBuyOrder.max));
        require(_address != 0x0);
        if (buyOrderLast == buyOrders.length) {
            buyOrders.length += 1;
        }
        buyOrders[buyOrderLast++] = OrderData({senderAddress: msg.sender, recipientAddress: _address, orderAmount: msg.value, orderTimestamp: now, rateLimit: _rateLimit});
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
    function createSellOrder(address _address, uint256 _tokensCount, uint256 _rateLimit) public notPaused {
        require((_tokensCount > limitSellOrder.min) && (_tokensCount < limitSellOrder.max));
        require(_address != 0x0);
        address tokenOwner = msg.sender;
        require(_tokensCount <= libreToken.balanceOf(tokenOwner));
        if (sellOrderLast == sellOrders.length) {
            sellOrders.length += 1;
        }
        sellOrders[sellOrderLast++] = OrderData({senderAddress: tokenOwner, recipientAddress: _address, orderAmount: _tokensCount, orderTimestamp: now, rateLimit: _rateLimit});
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

    /**
     * @dev Fills buy order from queue.
     * @param _orderID The order ID.
     */
    function fillBuyOrder(uint256 _orderID) internal returns (bool) {
        if (buyOrders[_orderID].senderAddress == 0x0) {
            return true; // ордер удалён, идём дальше
        }
        uint256 cryptoAmount = buyOrders[_orderID].orderAmount;
        uint256 tokensAmount = cryptoAmount.mul(cryptoFiatRateBuy).div(100);
        address senderAddress = buyOrders[_orderID].senderAddress;
        address recipientAddress = buyOrders[_orderID].recipientAddress;
        uint256 maxRate = buyOrders[_orderID].rateLimit;
        if ((maxRate != 0) && (cryptoFiatRateBuy < maxRate)) {
            RateBuyLimitOverflow(cryptoFiatRateBuy, maxRate, cryptoAmount);
            if (!cancelBuyOrder(_orderID)) {
                CouldntCancelOrder(true, _orderID);
            }
            return true; // go next orders
        }
        libreToken.mint(recipientAddress, tokensAmount);
        LogBuy(recipientAddress, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
        return true;
    }
    
    /**
     * @dev Fills sell order from queue.
     * @param _orderID The order ID.
     */
    function fillSellOrder(uint256 _orderID) internal returns (bool) {
        if (sellOrders[_orderID].senderAddress == 0x0) {
            return true; // ордер удалён, можно продолжать разгребать
        }
        address recipientAddress = sellOrders[_orderID].recipientAddress;
        address senderAddress = sellOrders[_orderID].senderAddress;
        uint256 tokensAmount = sellOrders[_orderID].orderAmount;
        uint256 cryptoAmount = tokensAmount.div(cryptoFiatRateBuy).mul(100);
        uint256 minRate = sellOrders[_orderID].rateLimit;
        if ((minRate != 0) && (cryptoFiatRateSell > minRate)) {
            RateBuyLimitOverflow(cryptoFiatRateBuy, minRate, cryptoAmount);
            if (!cancelSellOrder(_orderID)) {
                CouldntCancelOrder(false, _orderID);
            }
            return true; // go next orders
        }
        if (this.balance < cryptoAmount) {  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(cryptoFiatRateBuy).div(100);
            // слкдующую строчку продумать
            libreToken.mint(senderAddress, sellOrders[_orderID].orderAmount.sub(tokensAmount));
            cryptoAmount = this.balance;
        } else {
            tokensAmount = sellOrders[_orderID].orderAmount;
            cryptoAmount = tokensAmount.div(cryptoFiatRateBuy).mul(100);
        }
        if (!recipientAddress.send(cryptoAmount)) { 
            libreToken.mint(senderAddress, tokensAmount); // so as burned at sellTokens
            return false;                                         
        } 
        LogSell(recipientAddress, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
        return true;
    }

    /**
     * @dev Fill buy orders queue.
     */
    function fillBuyQueue() public notPaused returns (bool) {
        // TODO: при нарушении данного условия контракт окажется сломан. Нарушение малореально, но всё же найти выход
        require (buyOrderIndex < buyOrderLast);
        for (uint256 i = buyOrderIndex; i < buyOrderLast; i++) {
                if (!fillBuyOrder(i)) {
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
     * @dev Fill sell orders queue.
     */
    function fillSellQueue() public notPaused returns (bool) {
        // TODO: при нарушении данного условия контракт окажется сломан. Нарушение малореально, но всё же найти выход
        require (sellOrderIndex < sellOrderLast);
        for (uint i = sellOrderIndex; i < sellOrderLast; i++) {
            if (!fillSellOrder(i)) {
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

    /**
     * @dev Show buy order count.
     */
    function getBuyOrderFromTo() public view onlyOwner returns (uint256, uint256) {
        return (buyOrderIndex, buyOrderLast);
    }

    /**
     * @dev Show sell order count.
     */
    function getSellOrderFromTo() public view onlyOwner returns (uint256, uint256) {
        return (sellOrderIndex, sellOrderLast);
    }

    // про видимость подумать
    /**
     * @dev Touches oracles asking them to get new rates.
     */
    function requestUpdateRates() public notPaused {
        require (numEnabledOracles >= MIN_ENABLED_ORACLES);
        numWaitingOracles = 0;
        for (uint i = 0; i < oracleAddresses.length; i++) {
            if ((oracles[oracleAddresses[i]].enabled) && (oracles[oracleAddresses[i]].queryId == bytes32(""))) {
                bytes32 queryId = oracleInterface(oracleAddresses[i]).updateRate();
                OracleTouched(oracleAddresses[i], oracles[oracleAddresses[i]].name);
                oracles[oracleAddresses[i]].queryId = queryId;
                numWaitingOracles++;
            }
            timeUpdateRequested = now;
        } // foreach oracles
        OraclesTouched("Запущено обновление курсов");
    }

    /**
     * @dev Touches oracles asking them to get new rates.
     */
    function calculateRatesWithSpread() public notPaused {
        require (numWaitingOracles <= MIN_WAITING_ORACLES);
        UINTLog("оракулов ждёт", numWaitingOracles);
        require (numEnabledOracles-numWaitingOracles >= MIN_ENABLED_NOT_WAITING_ORACLES);
        UINTLog("вкл. оракулов не ждёт", numWaitingOracles);
        uint256 numReadyOracles = 0;
        uint256 minimalRate = MAX_UINT256;
        uint256 maximalRate = 0;
        for (uint i = 0; i < oracleAddresses.length; i++) {
            OracleData memory currentOracle = oracles[oracleAddresses[i]];
            if ((currentOracle.enabled) && (currentOracle.queryId == bytes32("")) && (currentOracle.cryptoFiatRate != 0)) {
                if (currentOracle.cryptoFiatRate < minimalRate) {
                    minimalRate = currentOracle.cryptoFiatRate;
                }
                if (currentOracle.cryptoFiatRate > maximalRate) {
                    maximalRate = currentOracle.cryptoFiatRate;
                }
                numReadyOracles++;
            }
        } // foreach oracles
        require (numReadyOracles >= MIN_READY_ORACLES);
        UINTLog("оракулов готово", numReadyOracles);
        uint256 middleRate = minimalRate.add(maximalRate).div(2);
        cryptoFiatRateBuy = minimalRate.sub(minimalRate.mul(buyFee).div(100).div(100)).sub(sellBuyDelta);
        cryptoFiatRateSell = maximalRate.add(maximalRate.mul(sellFee).div(100).div(100)).add(sellBuyDelta);
        cryptoFiatRate = middleRate;
    }

    /**
     * @dev The callback from oracles.
     * @param _rate The oracle ETH/USD rate.
     * @param _time Update time sent from oracle.
     */
    function oraclesCallback(uint256 _rate, uint256 _time) public notPaused { // дублирование _address и msg.sender
        OracleCallback(msg.sender, oracles[msg.sender].name, _rate);
        require(isOracle(msg.sender));
        if (oracles[msg.sender].queryId == bytes32("")) {
            TextLog("Oracle not waiting");
        } else {
           // all ok, we waited for it
           numWaitingOracles--;
           // maybe we should check for existance of structure oracles[_address]? to think about it
           oracles[msg.sender].cryptoFiatRate = _rate;
           oracles[msg.sender].updateTime = _time;
           oracles[msg.sender].queryId = 0x0;
           /*if (numWaitingOracles == 0) { // Добавить второе условие (будильник Ethereum)
                calculateRate();
                fillSellQueue();
                fillBuyQueue();
           }*/
        }
    }

    function processWaitingOracles() public notPaused {
        for (uint i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].enabled) {
                if (oracles[oracleAddresses[i]].queryId == bytes32("")) {
                    // оракул и так не ждёт
                }
                else {
                    // если оракул ждёт 10 минут и больше
                    if (oracles[oracleAddresses[i]].updateTime < now - 10 minutes) {
                        oracles[oracleAddresses[i]].cryptoFiatRate = 0; // быть неактуальным
                        oracles[oracleAddresses[i]].queryId = bytes32(""); // но не ждать
                        numWaitingOracles.sub(1);
                    } else {
                        revert(); // не даём завершить, пока есть ждущие менее 10 минут оракулы
                    }
                }
            }
        } // foreach oracles
    }
}