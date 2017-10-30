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

    address tokenAddress;
    token libreToken;

    uint256 timeUpdateRequested;

    uint256 constant MIN_ENABLED_ORACLES = 0; //2;
    uint256 constant MIN_WAITING_ORACLES = 2; //количество оракулов, которое допустимо омтавлять в ожидании
    uint256 constant MIN_READY_ORACLES = 1; //2;
    uint256 constant MIN_ENABLED_NOT_WAITING_ORACLES = 1; //2;

    //bool bankAllowTests = false; // для тестов
    

//  /**
//   * @dev Throws if called by any account other than the oracles.
//   */
  /*modifier onlyOracles() {
     for (uint i = 0; i < oracleAddresses.length; i++) {
            require(oracles[oracleAddresses[i]] == msg.sender);
      }
  }*/

    
    struct OrderData {
        address clientAddress;
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
//    uint256 orderCount = 0;

    function BasicBank() public {
        setBuyTokenLimits(0, MAX_UINT256);
        setSellTokenLimits(0, MAX_UINT256);
     }

    function cancelBuyOrder(uint256 _orderID) public onlyOwner {
        require (buyOrderIndex + _orderID < buyOrderLast);
        uint256 realOrderId = buyOrderIndex + _orderID;
        buyOrders[realOrderId].clientAddress.transfer(buyOrders[realOrderId].orderAmount);
        //delete(buyOrders[realOrderId]); 
        buyOrders[realOrderId].clientAddress = 0x0;
    }

    function cancelSellOrder(uint256 _orderID) public onlyOwner {
        require (sellOrderIndex + _orderID < sellOrderLast);
        uint256 realOrderId = sellOrderIndex + _orderID;
        libreToken.mint(sellOrders[realOrderId].clientAddress, sellOrders[realOrderId].orderAmount);
        //delete(sellOrders[realOrderId]);
        sellOrders[realOrderId].clientAddress = 0x0;
    }

    // без рекваеров, _orderID тут в старой системе в отличие от неSafe варианта
    // TODO: подогнать индексы ордеров под одну систему, наверно не нативную как в массиве, а от 0, как выше
    function cancelBuyOrderSafe(uint256 _orderID) public onlyOwner {
        bool sent = buyOrders[_orderID].clientAddress.send(buyOrders[_orderID].orderAmount);
        // а что делать если вернуло false (не отправилось) - подумать. снова ордер добавить?
        // помним, что эта функция выполняется во время разгребания оочереди, если лимит цены не подошёл,
        // и ордер надо вернуть
        sent; // от warning
        buyOrders[_orderID].clientAddress = 0x0;
    }

    // без рекваеров, _orderID тут в старой системе в отличие от неSafe варианта
    // TODO: подогнать индексы ордеров под одну систему, наверно не нативную как в массиве, а от 0, как выше
    function cancelSellOrderSafe(uint256 _orderID) public onlyOwner {
        libreToken.mint(sellOrders[_orderID].clientAddress, sellOrders[_orderID].orderAmount);
        sellOrders[_orderID].clientAddress = 0x0;
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

    // для автотестов
    //function allowTests() public { bankAllowTests = true; }
    //function areTestsAllowed() public view returns (bool) { return bankAllowTests; }

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
        createBuyOrder(msg.sender, 0);
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
    function createBuyOrder(address _address, uint256 _rateLimit) payable public {
        require((msg.value > getMinimumBuyTokens()) && (msg.value < getMaximumBuyTokens()));
        //if ((buyOrders.length == 0) && (sellOrders.length == 0)) {
        //    requestUpdateRates();
        //}
        if (buyOrderLast == buyOrders.length) {
            buyOrders.length += 1;
        }
        buyOrders[buyOrderLast++] = OrderData({clientAddress: _address, orderAmount: msg.value, orderTimestamp: now, rateLimit: _rateLimit});
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
    function createSellOrder(address _address, uint256 _tokensCount, uint256 _rateLimit) public {
        require((_tokensCount > getMinimumSellTokens()) && (_tokensCount < getMaximumSellTokens()));
        require(_tokensCount <= libreToken.balanceOf(_address));
        //if ((buyOrders.length == 0) && (sellOrders.length == 0)) {
        //    requestUpdateRates();
        //}
        if (sellOrderLast == sellOrders.length) {
            sellOrders.length += 1;
        }
        sellOrders[sellOrderLast++] = OrderData({clientAddress: _address, orderAmount: _tokensCount, orderTimestamp: now, rateLimit: _rateLimit});
        libreToken.burn(_address, _tokensCount);
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
    function fillBuyOrder(uint256 _orderID) public returns (bool) {
        if (buyOrders[_orderID].clientAddress == 0x0) {
            return true; // ордер удалён
        }
        uint256 cryptoAmount = buyOrders[_orderID].orderAmount;
        uint256 tokensAmount = cryptoAmount.mul(cryptoFiatRateBuy).div(100);
        address benificiar = buyOrders[_orderID].clientAddress;  
        uint256 maxRate = buyOrders[_orderID].rateLimit;
        if ((maxRate != 0) && (cryptoFiatRateBuy > maxRate)) {
            // todo: log
            cancelBuyOrderSafe(_orderID);
            return true; // go next orders
        }
    libreToken.mint(benificiar, tokensAmount);
        LogBuy(benificiar, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
        return true;
    }
    
    /**
     * @dev Fills sell order from queue.
     * @param _orderID The order ID.
     */
    function fillSellOrder(uint256 _orderID) public returns (bool) {
        if (sellOrders[_orderID].clientAddress == 0x0) {
            return true; // ордер удалён, можно продолжать разгребать
        }
        address beneficiar = sellOrders[_orderID].clientAddress;
        uint256 tokensAmount = sellOrders[_orderID].orderAmount;
        uint256 cryptoAmount = tokensAmount.div(cryptoFiatRateBuy).mul(100);
        uint256 minRate = sellOrders[_orderID].rateLimit;
        if ((minRate != 0) && (cryptoFiatRateSell < minRate)) {
            // todo: log
            cancelSellOrderSafe(_orderID);
            return true; // go next orders
        }
        if (this.balance < cryptoAmount) {  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(cryptoFiatRateBuy).div(100); 
            libreToken.mint(beneficiar, sellOrders[_orderID].orderAmount.sub(tokensAmount));
            cryptoAmount = this.balance;
        } else {
            tokensAmount = sellOrders[_orderID].orderAmount;
            cryptoAmount = tokensAmount.div(cryptoFiatRateBuy).mul(100);
        }
        if (!beneficiar.send(cryptoAmount)) { 
            libreToken.mint(beneficiar, tokensAmount); // so as burned at sellTokens
            return false;                                         
        } 
        LogSell(beneficiar, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
        return true;
    }

    /**
     * @dev Fill buy orders queue.
     */
    function fillBuyQueue() public returns (bool) {
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
    function fillSellQueue() public returns (bool) {
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
    function getBuyOrderCount() public view onlyOwner returns (uint256) {
        return buyOrderLast - buyOrderIndex;
    }

    /**
     * @dev Show sell order count.
     */
    function getSellOrderCount() public view onlyOwner returns (uint256) {
        return sellOrderLast - sellOrderIndex;
    }

    /**
     * @dev Show buy order amount.
     */
    function getBuyOrder(uint256 _orderId) public view onlyOwner returns (uint256, address, uint256, uint256) {
        uint256 realOrderId = buyOrderIndex + _orderId;
        require (realOrderId < buyOrderLast);
        require (buyOrders[realOrderId].clientAddress != 0x0);
        return (buyOrders[realOrderId].orderAmount, buyOrders[realOrderId].clientAddress, buyOrders[realOrderId].orderTimestamp,
                    buyOrders[realOrderId].rateLimit);
    }
    
    /**
     * @dev Show sell order amount.
     */
    function getSellOrder(uint256 _orderId) public view onlyOwner returns (uint256, address, uint256, uint256) {
        uint256 realOrderId = sellOrderIndex + _orderId;
        require (realOrderId < sellOrderLast);
        require (sellOrders[realOrderId].clientAddress != 0x0);
        return (sellOrders[realOrderId].orderAmount, sellOrders[realOrderId].clientAddress, buyOrders[realOrderId].orderTimestamp,
                    buyOrders[realOrderId].rateLimit);
    }
    
    // про видимость подумать
    /**
     * @dev Touches oracles asking them to get new rates.
     */
    function requestUpdateRates() public {
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

    // бета-аналог без условий по минимуму и максимуму и проценту
    function calculateRatesWithSpread() public {
        uint256 minimalRate = MAX_UINT256;
        uint256 maximalRate = 0;
        for (uint i = 0; i < oracleAddresses.length; i++) {
            if ((oracles[oracleAddresses[i]].enabled) && (oracles[oracleAddresses[i]].queryId == bytes32(""))) {
                if (oracles[oracleAddresses[i]].cryptoFiatRate < minimalRate) {
                    minimalRate = oracles[oracleAddresses[i]].cryptoFiatRate;
                }
                if (oracles[oracleAddresses[i]].cryptoFiatRate > maximalRate) {
                    maximalRate = oracles[oracleAddresses[i]].cryptoFiatRate;
                }
            }
        } // foreach oracles
        uint256 middleRate = minimalRate.add(maximalRate).div(2);
        cryptoFiatRateBuy = minimalRate.sub(middleRate.mul(buyFee).div(100));
        cryptoFiatRateSell = maximalRate.add(middleRate.mul(sellFee).div(100));
        cryptoFiatRate = middleRate;
    }

    // подумать над видимостью
    /**
     * @dev Calculates crypto/fiat rate from "oracles" array.
     */
    function calculateRate() public {
    //    require (numWaitingOracles <= MIN_WAITING_ORACLES);
        UINTLog("оракулов ждёт", numWaitingOracles);
    //    require (numEnabledOracles-numWaitingOracles >= MIN_ENABLED_NOT_WAITING_ORACLES);
        UINTLog("вкл. оракулов не ждёт", numWaitingOracles);
        uint256 numReadyOracles = 0;
        uint256 sumRating = 0;
        uint256 integratedRates = 0;
        // the average rate would be: (sum of rating*rate)/(sum of ratings)
        // so the more rating oracle has, the more powerful his rate is
        for (uint i = 0; i < oracleAddresses.length; i++) {
            OracleData storage currentOracleData = oracles[oracleAddresses[i]];
            if (now <= currentOracleData.updateTime + 3 minutes) { // защита от флуда обновлениями, потом мб уберём
                if ((currentOracleData.enabled) && (currentOracleData.queryId != bytes32(""))) {
                    numReadyOracles++;
                    sumRating += currentOracleData.rating;
                    integratedRates += currentOracleData.rating.mul(currentOracleData.cryptoFiatRate);
                }
            }
        }
    //    require (numReadyOracles >= MIN_READY_ORACLES);
        UINTLog("оракулов готово", numWaitingOracles);

        //UINTLog(sumRating);
        //uint256 finalRate = integratedRates.div(sumRating); // the formula is in upper comment
        //setCurrencyRate(finalRate);
        uint256 finalRate = 30000;

        cryptoFiatRate = finalRate;
        //currencyUpdateTime = now;
        // уходим от этой концепции, 500 нужно чтобы пока тоже работало
        cryptoFiatRateSell = finalRate.add(500);
        cryptoFiatRateBuy = finalRate.sub(500);

    }

    /**
     * @dev The callback from oracles.
     * @param _rate The oracle ETH/USD rate.
     * @param _time Update time sent from oracle.
     */
    function oraclesCallback(uint256 _rate, uint256 _time) public { // дублирование _address и msg.sender
        OracleCallback(msg.sender, oracles[msg.sender].name, _rate);
        require(!isNotOracle(msg.sender));
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

/*    function calculateSellPrice(uint256 _tokensAmount) internal returns (uint) {
        
    }

    function calculateBuyPrice(uint256 _tokensAmount) internal returns (uint) {
        
    }

    function calculateBuySpread(uint256 _tokensAmount) internal returns (uint) {
        
    }

    function calculateSellSpread(uint256 _tokensAmount) internal returns (uint) {
        
    }

    function isRateValid(uint _rate) internal returns (bool) {
        return true;
    }*/
}