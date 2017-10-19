pragma solidity ^0.4.10;
// Основной файл банка
import "./zeppelin/lifecycle/Pausable.sol";
import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/math/Math.sol";


interface token {
    /*function transfer(address receiver, uint amount);*/
    function balanceOf(address _owner) public returns (uint256);
    function mint(address _to,uint256 _amount) public;
    function getTokensAmount() public returns(uint256);
    function burn(address burner, uint256 _value) public;
}


interface oracleInterface {
    function update() public;
    function getName() constant public returns(bytes32);
}

/**
 * @title LibreBank.
 *
 * @dev Bank contract.
 */
contract LibreBank is Ownable, Pausable {
    using SafeMath for uint256;
    
    // сравнить с тем, что в oraclebase - dima
    event NewPriceTicker(address oracleAddress, string price);
    event LogBuy(address clientAddress, uint256 tokenAmount, uint256 etherAmount, uint256 buyPrice);
    event LogSell(address clientAddress, uint256 tokenAmount, uint256 etherAmount, uint256 sellPrice);
    event InsufficientOracleData(string description, uint256 oracleCount);
    /* event LogWithdrawal (uint256 EtherAmount, address addressTo, uint invertPercentage); */

    enum limitType { minUsdRate, maxUsdRate, minTransactionAmount, minTokensAmount, minSellSpread, maxSellSpread, minBuySpread, maxBuySpread, variance }
    enum rateType { target, issuance,burn, avg }
    enum feeType { first, second } ///TODO: Rename it later

 
    uint256 updateDataRequest;
    
    struct OracleData {
        bytes32 name;
        uint256 rating;
        bool enabled;
        bool waiting;
        uint256 updateTime; // time of callback
        uint256 cryptoFiatRate; // exchange rate
    }

    uint constant MAX_ORACLE_RATING = 10000;
    uint256 RELEVANCE_PERIOD = 5 minutes;
    mapping (address=>OracleData) oracles;
    address[] oracleAddresses;
    uint256[] rates;
    uint256[] fees;
    uint256 numWaitingOracles = 2**256 - 1; // init as maximum
    uint256 numEnabledOracles;
    uint256 dailyHigh; // 24h high
    uint256 dailyLow; // 24h low
    // maybe we should add weightWaitingOracles - sum of rating of waiting oracles
    uint256 timeUpdateRequested;
 
    uint256 public currencyUpdateTime;
    uint256 public cryptoFiatRate = 30000; // In $ cents

    uint256[] limits;
//    oracleInterface currentOracle;
    token libreToken;
    uint256 minTokenAmount = 1; // used in sellTokens(...)
    uint256 buyPrice; // in cents
    uint256 sellPrice; // in cents
    uint256 currentSpread; // in cents
    uint256 buySpread; // in cents
    uint256 sellSpread; // in cents
    uint256 avgRate; // Average rate
    // переменных пока избыточно, при создании алгоритма расчёта определимся
    // TODO: массив по enum

    /**
     * @dev Sets one of the limits.
     * @param _limitName The limit name.
     * @param _value The value.
     */
    function setLimitValue(limitType _limitName, uint256 _value) internal {
        limits[uint(_limitName)] = _value;
    }

    /**
     * @dev Gets value of one of the limits.
     * @param _limitName The limit name.
     */
    function getLimitValue(limitType _limitName) constant internal returns (uint256) {
        return limits[uint(_limitName)];
    }

    /**
     * @dev Set value of relevance period.
     * @param _relevancePeriod Relevance period.
     */
    function setRelevancePeriod(uint256 _relevancePeriod) onlyOwner {
        require(_relevancePeriod > 0);
        RELEVANCE_PERIOD = _relevancePeriod;
    }

    /**
     * @dev Gets minimal transaction amount.
     */
    function getMinTransactionAmount() constant external returns(uint256) {
        return getLimitValue(limitType.minTransactionAmount);
    }
    
    /**
     * @dev Sets minimal transaction amount (if ETH then in Wei).
     * @param _amount Minimal transaction amount.
     */
    function setMinTransactionAmount(uint256 _amount) onlyOwner public {
        setLimitValue(limitType.minTransactionAmount, _amount);
    }

    /**
     * @dev Sets minimal and maximal buy spreads.
     * @param _minBuySpread Minimal buy spread.
     * @param _maxBuySpread Maximal buy spread.
     */
    function setBuySpreadLimits(uint256 _minBuySpread, uint256 _maxBuySpread) onlyOwner public {
        setLimitValue(limitType.minBuySpread, _minBuySpread);
        setLimitValue(limitType.maxBuySpread, _maxBuySpread);
        
    }

    function getFee(feeType _type) internal returns(uint256) {
        return fees[_type];
    }

    function setFee(feeType _type,uint256 value) internal {
        fees[_type] = value;
    }
 
    /**
     * @dev Sets minimal and maximal sell spreads.
     * @param _minSellSpread Minimal sell spread.
     * @param _maxSellSpread Maximal sell spread.
     */
    function setSellSpreadLimits(uint256 _minSellSpread, uint256 _maxSellSpread) onlyOwner public {
        setLimitValue(limitType.minSellSpread, _minSellSpread);
        setLimitValue(limitType.maxSellSpread, _maxSellSpread);
    }

    /**
     * @dev Sets current buy and sell spreads spreads.
     * @param _buySpread Current buy spread.
     * @param _sellSpread Current sell spread.
     */
    function setSpread(uint256 _buySpread, uint256 _sellSpread) onlyOwner public {
        require((_buySpread > getLimitValue(limitType.minBuySpread)) && (_buySpread < getLimitValue(limitType.maxBuySpread)));
        require((_sellSpread > getLimitValue(limitType.minSellSpread)) && (_sellSpread < getLimitValue(limitType.maxSellSpread)));
        buySpread = _buySpread;
        sellSpread = _sellSpread;
    }

    /**
     * @dev Sets custom rate value
     * @param type Type of rate.
     * @param value Value to set.
     */    
    function setRate(rateType _type,uint256 value) internal {
        require(value > 0);
        rates[uint(_type)] = value;
    }

     /**
     * @dev Gets custom rate value
     * @param type Type of rate.
     */ 
    function getRate(rateType _type) constant returns(uint256) {
        return rates[uint(_type)];
    }

    /**
     * @dev Adds an oracle.
     * @param _address The oracle address.
     */
    function addOracle(address _address) onlyOwner public {
        require(_address != 0x0);
        oracleInterface currentOracleInterface = oracleInterface(_address);

        OracleData memory thisOracle = OracleData({name: currentOracleInterface.getName(), rating: MAX_ORACLE_RATING.div(2), 
                                                    enabled: true, waiting: false, updateTime: 0, cryptoFiatRate: 0});
        // insert the oracle into addr array & mapping
        oracleAddresses.push(_address);
        oracles[_address] = thisOracle;
    }

    /**
     * @dev Disable oracle.
     * @param _address The oracle address.
     */
    function disableOracle(address _address) public onlyOwner {
        oracles[_address].enabled = false;
    }

    /**
     * @dev Enable oracle.
     * @param _address The oracle address.
     */
    function enableOracle(address _address) public onlyOwner {
        oracles[_address].enabled = true;
    }

    /**
     * @dev Delete oracle.
     * @param _address The oracle address.
     */
    function deleteOracle(address _address) public onlyOwner {
        delete oracles[_address];
    }

    /**
     * @dev Gets oracle name.
     * @param _address The oracle address.
     */
    function getOracleName(address _address) public constant returns(bytes32) {
        return oracles[_address].name;
    }
    
    // Ограничение на периодичность обновления курса - не чаще чем раз в 5 минут
    modifier needUpdate() {
        require(!isRateActual());
        _;
    }

    /**
     * @dev Calculate current fund capitalization.
     */
    function getCapitalize() constant returns(uint256) {
        uint256 currentRate = getRate(rateType.target);
        return address(this).balance.mul(currentRate);
    }

    /**
     * @dev Calculate daily Volatility.
     */
    function getDailyVolatility() constant returns(uint256) {
        return dailyHigh.sub(dailyLow);
    }
    // WIP (Work in progress)
    function calculateRate() internal {
        uint256 targetRate = getRate(rateType.target);
        uint256 issuranceRate = targetRate.sub( getDailyVolatility().div(2) ).sub(getFee(feeType.first));
        uint256 burnRate = targetRate.add( getDailyVolatility().div(2) ).add(getFee(feeType.second));
        //TODO: Append limit and min\max checking
    }

     /**
     * @dev Calculate percents using fixed-float arithmetic.
     * @param numerator - Calculation numerator (first number)
     * @param denomirator - Calculation denomirator (first number)
     * @param precision - calc precision
     */
    function percent(uint numerator, uint denominator, uint precision) public constant returns(uint quotient) {
        uint _numerator  = numerator.mul(10 ** (precision+1));
        uint _quotient = _numerator.div(denominator).add(5).div(10);
        return _quotient;
    }


    /**
     * @dev Checks if the rate is up to date
     */
    function isRateActual() public constant returns(bool) {
        return (now <= currencyUpdateTime + RELEVANCE_PERIOD);
    }

    function libreBank(address _tokenContract) public {
        libreToken = token(_tokenContract);
    }
    
    /**
     * @dev Changes token contract address.
     */
    function changeTokenContract(address _tokenContract) onlyOwner public {
        libreToken = token(_tokenContract);
    }

    /**
     * @dev Receives donations.
     */
    function donate() payable public {}

    /**
     * @dev cryptoFiatRate getter.
     */
    function getTokenPrice() needUpdate public constant returns(uint256) {
        return cryptoFiatRate;
    }

    /**
     * @dev Gets total tokens count.
     */
    function totalTokenCount() public returns (uint256) {
        return libreToken.getTokensAmount();
    }

    /**
     * @dev Transfers crypto.
     */
   function withdrawCrypto(address _beneficiar) onlyOwner public {
        _beneficiar.transfer(this.balance);
    }

    /**
     * @dev Sets currency rate and updates timestamp.
     */
    function setCurrencyRate(uint256 _rate) onlyOwner internal {
        bool validRate = (_rate > getLimitValue(limitType.minUsdRate)) && (_rate < getLimitValue(limitType.maxUsdRate));
        require(validRate);
        cryptoFiatRate = _rate;
        currencyUpdateTime = now;
    }

//    function updateRate() public needUpdate {
//        requestUpdateRates();
//    }

    // пока на все случаи возможные
    uint256 constant MIN_ENABLED_ORACLES = 2;
    uint256 constant MIN_WAITING_ORACLES = 2;
    uint256 constant MIN_READY_ORACLES = 2;
    uint256 constant MIN_ENABLED_NOT_WAITING_ORACLES = 2;


    /**
     * @dev Touches oracles asking them to get new rates.
     */
    function requestUpdateRates() internal returns (bool) {
        if (numEnabledOracles <= MIN_ENABLED_ORACLES) {
            InsufficientOracleData("Not enough enabled oracles to request updating rates", numEnabledOracles);
            return false;
        } // 1-2 enabled oracles - false result. we need more oracles. But anyway requests sent
        // numWaitingOracles goes -1 after each callback
        numWaitingOracles = 0;
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].enabled) {
                oracleInterface(oracleAddresses[i]).update();
                oracles[oracleAddresses[i]].waiting = true;
                numWaitingOracles++;
            }
            timeUpdateRequested = now;
            // but we can not refer to return (i don't do throw here because update() already sent) - think about number of needed oracles
        } // foreach oracles
        return true;
    }

    /**
     * @dev Calculates crypto/fiat rate from "oracles" array.
     */
    function getRate() internal returns (bool) {
        // check if numWaitingOracles is small enough in compare with all oracles
        //require (numWaitingOracles <= MIN_WAITING_ORACLES);
        //require ((numWaitingOracles!=0) && (numEnabledOracles-numWaitingOracles >= MIN_ENABLED_NOT_WAITING_ORACLES)); // if numWaitingOracles not zero, check if count of ready oracles > 3
                                                                                  // TODO: think about oracle weight and maybe use weights instead of count (num...) 
        if (numWaitingOracles > MIN_WAITING_ORACLES) {
            InsufficientOracleData("Too many oracles are waiting for rates now.", numWaitingOracles);
            return false;
        }
        uint256 numReceivedOracles = numEnabledOracles - numWaitingOracles;
        if (numReceivedOracles < MIN_ENABLED_NOT_WAITING_ORACLES) {
            InsufficientOracleData("Not enough enabled oracles with received rate.", numReceivedOracles);
            return false;
        }
        uint256 numReadyOracles = 0;
        uint256 sumRatings = 0;
        uint256 integratedRates = 0;
        // the average rate would be: (sum of rating*rate)/(sum of ratings)
        // so the more rating oracle has, the more powerful his rate is
        for (uint i = 0; i < oracleAddresses.length; i++) {
            OracleData storage currentOracle = oracles[oracleAddresses[i]];
            if (now <= currentOracle.updateTime + 5 minutes) { //up to date
                if (currentOracle.enabled) {
                    numReadyOracles++;
                    // values for calculating the rate
                    sumRatings += currentOracle.rating;
                    integratedRates += currentOracle.rating.mul(currentOracle.cryptoFiatRate);
                }
            } else { // oracle's rate is older than 5 mins
                // just nothing? we don't increment readyOracles
            } // if old data
        } // foreach oracles
        if (numReadyOracles > MIN_READY_ORACLES) {
            InsufficientOracleData("Not enough not outdated oracles.", numReadyOracles);
            return false;
        } // maybe change/add rating of oracles
        if (numEnabledOracles.div(numReadyOracles) > 2) {
            InsufficientOracleData("Ready oracles are less than 50% of all enabled oracles.", numReadyOracles);
            return false;
        } // numReadyOracles!=0 is already; need more than or equal to 50% ready oracles
        // here we can count the rate and return true
        uint256 finalRate = integratedRates.div(sumRatings); // formula is in upper comment
        setCurrencyRate(finalRate);
        return true;
    }

    /**
     * @dev The callback from oracles.
     * @param _address The oracle address.
     * @param _rate The oracle ETH/USD rate.
     * @param _time Update time sent from oracle.
     */
    function oraclesCallback(address _address, uint256 _rate, uint256 _time) public {
        // Implement it later
        if (!oracles[_address].waiting) {
            // we didn't wait for this oracul
            // to do - think what to do, this information is useful, but why it is late or not wanted?
        } else {
            // all ok, we waited for it
            numWaitingOracles--;
            // maybe we should check for existance of structure oracles[_address]? to think about it
            oracles[_address].cryptoFiatRate = _rate;
            oracles[_address].updateTime = _time;
            oracles[_address].waiting = false;
            // we don't need to update oracle name, so?
            // so i deleted 'string name' from func's arguments
            getRate(); // returns true or false, maybe we will want check it later
        }
    }

    // ***************************************************************************

    // Buy token by sending ether here
    //
    // Price is being determined by the algorithm in oraclesCallback()
    // You can also send the ether directly to the contract address   
    
    enum OrderType { ORDER_BUY, ORDER_SELL }
    struct OrderData {
        OrderType orderType;
        address clientAddress;
        uint256 orderAmount;
        uint256 orderTimestamp;
        //uint ClientLimit;
    } 
    OrderData[] orders; // очередь ордеров
    uint256 orderCount = 0;

    function () payable external {
        buyTokens(msg.sender);
    }

    /**
     * @dev Lets user buy tokens.
     * @param _beneficiar The buyer's address.
     */
    function buyTokens(address _beneficiar) payable public {
        require(_beneficiar != 0x0);
        require(msg.value > getLimitValue(limitType.minTransactionAmount));
        if (!isRateActual()) {                   // проверяем курс на актуальность
            orders.push(OrderData(OrderType.ORDER_BUY, _beneficiar, msg.value, now)); // ставим ордер в очередь
            // ^ при любых ранее удалённых элементах добавляет в конец - проверил
            //updateRate();
            return; // и выходим из функции
        }
        uint256 tokensAmount = msg.value.mul(buyPrice).div(100);  
        libreToken.mint(_beneficiar, tokensAmount);
        LogBuy(_beneficiar, tokensAmount, msg.value, buyPrice);
    }

    /**
     * @dev Fills buy order from queue.
     * @param _orderID The order ID.
     */
    function fillBuyOrder(uint256 _orderID) internal returns (bool) {
        if (!isRateActual()) {
            return false;
        }
        uint256 cryptoAmount = orders[_orderID].orderAmount;
        uint256 tokensAmount = cryptoAmount.mul(buyPrice).div(100);
        address benificiar = orders[_orderID].clientAddress;  
        libreToken.mint(benificiar, tokensAmount);
        LogBuy(benificiar, tokensAmount, cryptoAmount, buyPrice);
        return true;
    }
  
    /**
     * @dev Lets user sell tokens.
     * @param _amount The amount of tokens.
     */
    function sellTokens(uint256 _amount) public {
        require (libreToken.balanceOf(msg.sender) >= _amount);        // checks if the sender has enough to sell
        require (_amount >= getLimitValue(limitType.minTokensAmount));
        
        uint256 tokensAmount;
        uint256 cryptoAmount = _amount.div(sellPrice).mul(100);
        if (cryptoAmount > this.balance) {                  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(sellPrice).div(100); // нужна дополнительная проверка, на случай повторного запроса при пустых резервах банка
            cryptoAmount = this.balance;
        } else {
            tokensAmount = _amount;
        }
        if (!isRateActual()) {                   // проверяем курс на актуальность
            libreToken.burn(msg.sender, tokensAmount); // уменьшаем баланс клиента (в случае отмены ордера, токены клиенту возвращаются)
            orders.push(OrderData(OrderType.ORDER_SELL, msg.sender, tokensAmount, now)); // ставим ордер в очередь
            //updateRate();
            return; // и выходим из функции
        }
        
        msg.sender.transfer(cryptoAmount);
        libreToken.burn(msg.sender, tokensAmount); 
        LogSell(msg.sender, tokensAmount, cryptoAmount, sellPrice);
    }

    /**
     * @dev Fills sell order from queue.
     * @param _orderID The order ID.
     */
    function fillSellOrder(uint256 _orderID) internal returns (bool) {
        address beneficiar = orders[_orderID].clientAddress;
        uint256 tokensAmount = orders[_orderID].orderAmount;
        uint256 cryptoAmount = tokensAmount.div(sellPrice).mul(100);
        if (this.balance < cryptoAmount) {  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(sellPrice).div(100); 
            libreToken.mint(beneficiar, orders[_orderID].orderAmount.sub(tokensAmount));
            cryptoAmount = this.balance;
        } else {
            tokensAmount = orders[_orderID].orderAmount;
            cryptoAmount = tokensAmount.div(sellPrice).mul(100);
        }
        if (!beneficiar.send(cryptoAmount)) { 
            libreToken.mint(beneficiar, tokensAmount); // so as burned at sellTokens
            return false;                                         
        } 
        LogSell(beneficiar, tokensAmount, cryptoAmount, sellPrice);
        return true;
    }

    uint256 bottomOrderIndex = 0; // поднять потом наверх

    /**
     * @dev Fills order queue.
     */
    function fillOrders() public returns (bool) {
        require (bottomOrderIndex < orders.length);
        uint ordersLength = orders.length;
        for (uint i = bottomOrderIndex; i < ordersLength; i++) {
            if (orders[i].orderType == OrderType.ORDER_BUY) {
                if (!fillBuyOrder(i)) {
                    bottomOrderIndex = i;
                    return false;
                } 
            } else {
                if (!fillSellOrder(i)) {
                    bottomOrderIndex = i;
                    return false;
                }
            }
            delete(orders[i]); // в solidity массив не сдвигается, тут будет нулевой элемент
        } // for
        bottomOrderIndex = 0;
        // см. ответ про траты газа:
        // https://ethereum.stackexchange.com/questions/3373/how-to-clear-large-arrays-without-blowing-the-gas-limit
        return true;
    } // function fillOrders()


    /**
    * @dev Reject all ERC23 compatible tokens
    * @param from_ address The address that is transferring the tokens
    * @param value_ uint256 the amount of the specified token
    * @param data_ Bytes The data passed from the caller.
    */
    function tokenFallback(address from_, uint256 value_, bytes data_) external {
        revert();
    }
}


