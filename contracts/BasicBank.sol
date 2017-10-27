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
    event UINTLog(uint256 data);
    event BuyOrderCreated(uint256 amount);
    event SellOrderCreated(uint256 amount);
    event LogBuy(address clientAddress, uint256 tokenAmount, uint256 cryptoAmount, uint256 buyPrice);
    event LogSell(address clientAddress, uint256 tokenAmount, uint256 cryptoAmount, uint256 sellPrice);
    event OrderQueueGeneral(string description);

    address tokenAddress;
    token libreToken;

    uint256 constant MAX_UINT256 = 2**256 - 1;

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
        bool deleted;
        //uint ClientLimit;
    }

    OrderData[] buyOrders; // очередь ордеров на покупку
    OrderData[] sellOrders; // очередь ордеров на покупку

    uint256 orderCount = 0;

    function BasicBank() public {
        setBuyTokenLimits(0, MAX_UINT256);
        setSellTokenLimits(0, MAX_UINT256);
     }

    function cancelBuyOrder (uint256 _orderID) public onlyOwner {
        require (buyOrderIndex + _orderID < buyOrderLast);
        uint256 realOrderId = buyOrderIndex + _orderID;
        buyOrders[realOrderId].clientAddress.transfer(buyOrders[realOrderId].orderAmount);
        delete(buyOrders[realOrderId]); 
    }

    function cancelSellOrder (uint256 _orderID) public onlyOwner {
        require (sellOrderIndex + _orderID < sellOrderLast);
        uint256 realOrderId = sellOrderIndex + _orderID;
        libreToken.mint(sellOrders[realOrderId].clientAddress, sellOrders[realOrderId].orderAmount);
        delete(sellOrders[realOrderId]);
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
    function getToken() view public returns (address) {
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
        createBuyOrder(msg.sender);
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
     */
    function createBuyOrder(address _address) payable public {
        require((msg.value > getMinimumBuyTokens()) && (msg.value < getMaximumBuyTokens()));
        if ((buyOrders.length == 0) && (sellOrders.length == 0)) {
            requestUpdateRates();
        }
        if (buyOrderLast == buyOrders.length) {
            buyOrders.length += 1;
        }
        buyOrders[buyOrderLast++] = OrderData({clientAddress: _address, orderAmount: msg.value, orderTimestamp: now, deleted: false});
        BuyOrderCreated(msg.value);
    }

    /**
     * @dev Creates sell order.
     * @param _address Beneficiar.
     * @param _tokensCount Amount of tokens to sell.
     */
    function createSellOrder(address _address, uint256 _tokensCount) public {
        require((_tokensCount > getMinimumSellTokens()) && (_tokensCount < getMaximumSellTokens()));
        require(_tokensCount <= libreToken.balanceOf(_address));
        if ((buyOrders.length == 0) && (sellOrders.length == 0)) {
            requestUpdateRates();
        }
        if (sellOrderLast == sellOrders.length) {
            sellOrders.length += 1;
        }
        sellOrders[sellOrderLast++] = OrderData({clientAddress: _address, orderAmount: _tokensCount, orderTimestamp: now, deleted: false});
        libreToken.burn(_address, _tokensCount);
        SellOrderCreated(_tokensCount); 
    }

    /**
     * @dev Creates sell order.
     * @param _tokensCount Amount of tokens to sell.
     */
    function createSellOrder(uint256 _tokensCount) public {
        require((_tokensCount > getMinimumSellTokens()) && (_tokensCount < getMaximumSellTokens()));
        require(_tokensCount <= libreToken.balanceOf(msg.sender));
        if ((buyOrders.length == 0) && (sellOrders.length == 0)) {
            requestUpdateRates();
        }
        if (sellOrderLast == sellOrders.length) {
            sellOrders.length += 1;
        }
        sellOrders[sellOrderLast++] = OrderData({clientAddress: msg.sender, orderAmount: _tokensCount, orderTimestamp: now, deleted: false});
        libreToken.burn(msg.sender, _tokensCount);
        SellOrderCreated(_tokensCount); 
    }

    /**
     * @dev Fills buy order from queue.
     * @param _orderID The order ID.
     */
    function fillBuyOrder(uint256 _orderID) public returns (bool) {
        if (buyOrders[_orderID].deleted) {
            return true; // ордер удалён
        }
        uint256 cryptoAmount = buyOrders[_orderID].orderAmount;
        uint256 tokensAmount = cryptoAmount.mul(cryptoFiatRateBuy).div(100);
        address benificiar = buyOrders[_orderID].clientAddress;  
        libreToken.mint(benificiar, tokensAmount);
        LogBuy(benificiar, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
        return true;
    }
    
    /**
     * @dev Fills sell order from queue.
     * @param _orderID The order ID.
     */
    function fillSellOrder(uint256 _orderID) public returns (bool) {
        if (sellOrders[_orderID].deleted) {
            return true; // ордер удалён
        }
        address beneficiar = sellOrders[_orderID].clientAddress;
        uint256 tokensAmount = sellOrders[_orderID].orderAmount;
        uint256 cryptoAmount = tokensAmount.div(cryptoFiatRateBuy).mul(100);
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

// public для тестов
    uint256 public buyOrderIndex = 0; // поднять потом наверх
    uint256 public buyOrderLast = 0;
    uint256 public sellOrderIndex = 0;
    uint256 public sellOrderLast = 0;

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
    function getBuyOrderValue(uint256 _orderId) public view onlyOwner returns (uint256) {
        uint256 realOrderId = buyOrderIndex + _orderId;
        require (realOrderId < buyOrderLast);
        require (!buyOrders[realOrderId].deleted);
        return buyOrders[realOrderId].orderAmount;
    }
    
    /**
     * @dev Show sell order amount.
     */
    function getSellOrderValue(uint256 _orderId) public view onlyOwner returns (uint256) {
        uint256 realOrderId = sellOrderIndex + _orderId;
        require (realOrderId < sellOrderLast);
        require (!sellOrders[realOrderId].deleted);
        return sellOrders[realOrderId].orderAmount;
    }
    
    // про видимость подумать
    /**
     * @dev Touches oracles asking them to get new rates.
     */
    function requestUpdateRates() public {
        require (numEnabledOracles >= MIN_ENABLED_ORACLES);
        numWaitingOracles = 0;
        for (uint i = 0; i < oracleAddresses.length; i++) {
            if ((oracles[oracleAddresses[i]].enabled) && (oracles[oracleAddresses[i]].queryId == 0x0)) {
                bytes32 queryId = oracleInterface(oracleAddresses[i]).updateRate();
                OracleTouched(oracleAddresses[i], oracles[oracleAddresses[i]].name);
                oracles[oracleAddresses[i]].queryId = queryId;
                numWaitingOracles++;
            }
            timeUpdateRequested = now;
        } // foreach oracles
        OraclesTouched("Запущено обновление курсов");
    }

    function dummySpenderDelegate() public {
        address(this).delegatecall(bytes4(sha3("dummySpender()")));
    }

    uint256 dummyData;
    function dummySpender() public {
        for (uint i = 1; i < 250; i++) {
            dummyData += i * 2;
        }
    }

    // подумать над видимостью
    /**
     * @dev Calculates crypto/fiat rate from "oracles" array.
     */
    function calculateRate() public {
    //    require (numWaitingOracles <= MIN_WAITING_ORACLES);
    //    require (numEnabledOracles-numWaitingOracles >= MIN_ENABLED_NOT_WAITING_ORACLES);

        uint256 numReadyOracles = 0;
        uint256 sumRating = 0;
        uint256 integratedRates = 0;
        // the average rate would be: (sum of rating*rate)/(sum of ratings)
        // so the more rating oracle has, the more powerful his rate is
        for (uint i = 0; i < oracleAddresses.length; i++) {
            OracleData storage currentOracleData = oracles[oracleAddresses[i]];
            if (now <= currentOracleData.updateTime + 3 minutes) { // защита от флуда обновлениями, потом мб уберём
                if ((currentOracleData.enabled) && (currentOracleData.queryId != 0x0)) {
                    numReadyOracles++;
                    sumRating += currentOracleData.rating;
                    integratedRates += currentOracleData.rating.mul(currentOracleData.cryptoFiatRate);
                }
            }
        }
    //    require (numReadyOracles >= MIN_READY_ORACLES);

        uint256 finalRate = integratedRates.div(sumRating); // the formula is in upper comment
        //setCurrencyRate(finalRate);


        cryptoFiatRate = finalRate;
        //currencyUpdateTime = now;
        cryptoFiatRateSell = finalRate.add(sellSpread.mul(sellFee).div(10000));
        cryptoFiatRateBuy = finalRate.sub(buySpread.mul(buyFee).div(10000));

    }

    /**
     * @dev The callback from oracles.
     * @param _rate The oracle ETH/USD rate.
     * @param _time Update time sent from oracle.
     */
    function oraclesCallback(uint256 _rate, uint256 _time) public { // дублирование _address и msg.sender
        OracleCallback(msg.sender, oracles[msg.sender].name, _rate);
        require(!isNotOracle(msg.sender));
        if (oracles[msg.sender].queryId != 0x0) {
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

    function calculateSellPrice(uint256 _tokensAmount) internal returns (uint) {
        
    }

    function calculateBuyPrice(uint256 _tokensAmount) internal returns (uint) {
        
    }

    function calculateBuySpread(uint256 _tokensAmount) internal returns (uint) {
        
    }

    function calculateSellSpread(uint256 _tokensAmount) internal returns (uint) {
        
    }

    function isRateValid(uint _rate) internal returns (bool) {
        return true;
    }
}