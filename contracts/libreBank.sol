pragma solidity ^0.4.10;
// Основной файл банка
import "./zeppelin/lifecycle/Pausable.sol";
import "./zeppelin/math/SafeMath.sol";


interface token {
    /*function transfer(address receiver, uint amount);*/
    function balanceOf(address _owner) public returns (uint256);
    function mint(address _to,uint256 _amount) public;
    function getTokensAmount() public returns(uint256);
    function burn(address burner, uint256 _value) public;
}

interface oracleInterface {
    function update();
    function getName() constant public returns(bytes32);
}


contract libreBank is Ownable, Pausable {
    using SafeMath for uint256;
    
    enum limitType { minUsdRate, maxUsdRate, minTransactionAmount, minTokensAmount, minSellSpread, maxSellSpread, minBuySpread, maxBuySpread }
    event NewPriceTicker(address oracleAddress, string price);
    event LogBuy(address clientAddress, uint256 tokenAmount, uint256 etherAmount, uint256 buyPrice);
    event LogSell(address clientAddress, uint256 tokenAmount, uint256 etherAmount, uint256 sellPrice);
    /*
    event LogWithdrawal (uint256 EtherAmount, address addressTo, uint invertPercentage);
    */

    uint256 updateDataRequest;
    
    struct oracleData {
        bytes32 name;
        uint256 rating;
        bool enabled;
        bool waiting;
        uint256 updateTime; // time of callback
        uint256 ethUsdRate; // exchange rate
    }

    uint constant maxOracleRating = 10000;

    mapping (address=>oracleData) oracles;
    address[] oracleAddresses;

    uint256 numWaitingOracles = 2**256 - 1; // init as maximum
    uint256 numEnabledOracles;
    // maybe we should add weightWaitingOracles - sum of rating of waiting oracles
    uint256 timeUpdateRequested;
// end new oracleData
 
    uint256 public currencyUpdateTime;
    uint256 public ethUsdRate = 30000; // In $ cents

    uint256[] limits;
    oracleInterface currentOracle;
    token libreToken;
    uint256 minTokenAmount = 1; // used in sellTokens(...)
    uint256 buyPrice; // in cents
    uint256 sellPrice; // in cents
    uint256 currentSpread; // in cents
    uint256 buySpread; // in cents
    uint256 sellSpread; // in cents
    // переменных пока избыточно, при создании алгоритма расчёта определимся

    function setLimitValue(limitType limitName, uint256 value) internal {
        limits[uint(limitName)] = value;
    }

    function getLimitValue(limitType limitName) internal returns (uint256) {
        return limits[uint(limitName)];
    }

    function getMinTransactionAmount() constant external returns(uint256) {
        return getLimitValue(limitType.minTransactionAmount);
    }
    
    function setMinTransactionAmount(uint256 amountInWei) onlyOwner {
        setLimitValue(limitType.minTransactionAmount,amountInWei);
    }

    function setBuySpreadLimits(uint256 _minBuySpread, uint256 _maxBuySpread) onlyOwner {
        setLimitValue(limitType.minBuySpread, _minBuySpread);
        setLimitValue(limitType.maxBuySpread, _maxBuySpread);
        
    }

    function setSellSpreadLimits(uint256 _minSellSpread, uint256 _maxSellSpread) onlyOwner {
        setLimitValue(limitType.minSellSpread, _minSellSpread);
        setLimitValue(limitType.maxSellSpread, _maxSellSpread);
    }

    function setSpread(uint256 _buySpread, uint256 _sellSpread) onlyOwner {
        require((_buySpread > getLimitValue(limitType.minBuySpread)) && (_buySpread < getLimitValue(limitType.maxBuySpread)));
        require((_sellSpread > getLimitValue(limitType.minSellSpread)) && (_sellSpread < getLimitValue(limitType.maxSellSpread)));
        buySpread = _buySpread;
        sellSpread = _sellSpread;
    }

    /**
     * @dev Adds an oracle
     * @param _address The oracle address
     */
    function addOracle(address _address) onlyOwner {
        require(_address != 0x0);
        oracleInterface currentOracleInterface = oracleInterface(_address);
        //oracleData memory thisOracle = new oracleData(oracleInterface.getName(),oracleAddress,0,true);
        //  what is initial ethUsdRate of oracle? 0?
        oracleData memory thisOracle = oracleData({name: currentOracleInterface.getName(), rating: maxOracleRating.div(2), 
                                                    enabled: true, waiting: false, updateTime: 0, ethUsdRate: 0});
        // insert the oracle into addr array & mapping
        oracleAddresses.push(_address);
        oracles[_address] = thisOracle;
    }

    /**
     * @dev Gets oracle name
     * @param _address The oracle address
     */
    function getOracleName(address _address) public constant returns(bytes32) {
        return oracles[_address].name;
    }
    
    // Ограничие на периодичность обновления курса - не чаще чем раз в 5 минут
    modifier needUpdate() {
        require(!isRateActual());
        _;
    }

    function isRateActual() public constant returns(bool) {
        return (now <= currencyUpdateTime + 5 minutes);
    }

    function libreBank(address coinsContract) {
        libreToken = token(coinsContract);
    }
    
    function donate() payable {}

    function getTokenPrice() returns(uint256) {
        // Implement price calc logic later
        uint256 tokenPrice = 100; // In $ cent
        return tokenPrice;
    }

    

    function setTokenToSell(address tokenAddress) onlyOwner {
        libreToken = token(tokenAddress);
    }

    function totalTokens() returns (uint256) {
        return libreToken.getTokensAmount();
    }

    function withdrawEther(address beneficiar) onlyOwner {
        beneficiar.send(this.balance);
    }


    function setCurrencyRate(uint256 rate) onlyOwner {
        bool validRate = (rate > getLimitValue(limitType.minUsdRate)) && (rate < getLimitValue(limitType.maxUsdRate));
        require(validRate);
        ethUsdRate = rate;
        currencyUpdateTime = now;
    }

    function updateRate() needUpdate {
        requestUpdateRates();
        // I think we don't need the next code
        // the function should wait for callbacks or we should change the way it works
        // !!!!
        // следующий код здесь не нужен
        // нужно или ждать тут колбэки или не использовать эту функцию

        /*currentSpread = SafeMath.add(limits[limitType.minBuySpread], limits[limitType.minSellSpread]);
        uint256 halfSpread = SafeMath.div(currentSpread, 2);
        // require(halfSpread < currentSpread); // -- not sure if we need to check (possibly no), I need to research types and possible vulnerabilities - Dima
        buyPrice = SafeMath.sub(ethUsdRate, halfSpread);
        sellPrice = SafeMath.add(ethUsdRate, halfSpread);*/
    }

    function requestUpdateRates() private returns (bool) {
        // uint256[] oracleResults; // - was not used
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            // numWaitingOracles goes -1 after each callback
            numWaitingOracles = 0;
            if (oracles[oracleAddresses[i]].enabled) {
                oracleInterface(oracleAddresses[i]).update();
                oracles[oracleAddresses[i]].waiting = true;
                numWaitingOracles++;
            }
            timeUpdateRequested = now;
            if (numWaitingOracles <= 2) { return false; } // 1-2 enabled oracles - false result. we need more oracles
            // but we can not refer to return (i don't do throw here because update() already sent) - think about number of needed oracles
            return true;
        } // foreach oracles
    }

    function getRate() private returns (bool) {
        // check if numWaitingOracles is small enough in compare with all oracles
        require (numWaitingOracles < 3);
        require ((numWaitingOracles!=0) && (numEnabledOracles-numWaitingOracles>3)); // if numWaitingOracles not zero, check if count of ready oracles > 3
                                                                                  // TODO: think about oracle weight and maybe use weights instead of count (num...) 
        uint256 numReadyOracles = 0;
        uint256 sumRatings = 0;
        uint256 integratedRates = 0;
        // the average rate would be: (sum of rating*rate)/(sum of ratings)
        // so the more rating oracle has, the more powerful his rate is
        for (uint i = 0; i < oracleAddresses.length; i++) {
            oracleData currentOracle = oracles[oracleAddresses[i]];
            if (now <= currentOracle.updateTime + 5 minutes) { //up to date
                if (currentOracle.enabled) {
                    numReadyOracles++;
                    // values for calculating the rate
                    sumRatings += currentOracle.rating;
                    integratedRates += currentOracle.rating.mul(currentOracle.ethUsdRate);
                }
            } else { // oracle's rate is older than 5 mins
                // just nothing? we don't increment readyOracles
            } // if old data
        } // foreach oracles
        require (numReadyOracles > 2); // maybe change/add rating of oracles
        require (numEnabledOracles.div(numReadyOracles) < 2); // numReadyOracles!=0 is already; need more than 50% ready oracles
        // here we can count the rate and return true
        uint256 finalRate = integratedRates.div(sumRatings); // formula is in upper comment
        setCurrencyRate(finalRate);
        return true;
    }

    /**
     * @dev The callback from oracles
     * @param _address The oracle address
     * @param _rate The oracle ETH/USD rate
     * @param _time Update time sent from oracle
     */
    function oraclesCallback(address _address, uint256 _rate, uint256 _time) {
        // Implement it later
        if (!oracles[_address].waiting) {
            // we didn't wait for this oracul
            // to do - think what to do, this information is useful, but why it is late or not wanted?
        } else {
            // all ok, we waited for it
            numWaitingOracles--;
            // maybe we should check for existance of structure oracles[_address]? to think about it
            oracles[_address].ethUsdRate = _rate;
            oracles[_address].updateTime = _time;
            oracles[_address].waiting = false;
            // we don't need to update oracle name, so?
            // so i deleted 'string name' from func's arguments
        }
        // so this callback function JUST updates the gotten rate value and timestamp
        // new getRate function checks if we can count the rate (due to count of good callbacks) and counts
        // we shold call getRate when we need it       
    }

    // ***************************************************************************

    // Buy token by sending ether here
    //
    // Price is being determined by the algorithm in oraclesCallback()
    // You can also send the ether directly to the contract address   
    
    OrderData[] orders; // очередь ордеров
    struct OrderData {
        bool isBuy; // True = Buy, False = sell
        address clientAddress;
        uint256 orderAmount;
        uint256 orderTimestamp;
        //uint ClientLimit;
    } 

    function () payable external {
        buyTokens(msg.sender);
    }

    function buyTokens (address benificiar) payable public {
        require(msg.value > getLimitValue(limitType.minTransactionAmount));
        if (!isRateActual()) {                   // проверяем курс на актуальность

            orders.push(OrderData(true, benificiar, msg.value, now)); // ставим ордер в очередь
            // Олег, проверь строчкой выше - добавил beneficiar как адрес клиента, верно? - Дима
            updateRate(); // и выходим из функции
            // тут вроде нужен return или я ошибаюсь? - дима
        }
        // in case of possible overflows should do assert() or require() for sellPrice>ethUsdRate and buyPrice<..., but we need a small research
        uint256 tokensAmount = msg.value.mul(buyPrice).div(100);  
        libreToken.mint(benificiar, tokensAmount);
        LogBuy(benificiar, tokensAmount, msg.value, buyPrice);
    }

    function buyAfter (uint256 orderID) internal {
        uint256 ethersAmount = orders[orderID].orderAmount;
        uint256 tokensAmount = ethersAmount.mul(buyPrice).div(100);
        address benificiar = orders[orderID].clientAddress;  
        libreToken.mint(benificiar, tokensAmount);
        LogBuy(benificiar, tokensAmount, ethersAmount, buyPrice);
    }
  
    function sellTokens(uint256 _amount) public {
        require (libreToken.balanceOf(msg.sender) >= _amount);        // checks if the sender has enough to sell
        require (_amount >= getLimitValue(limitType.minTokensAmount));
        //uint256 
        uint256 tokensAmount;
        uint256 ethersAmount = _amount.div(sellPrice).mul(100);
        if (ethersAmount > this.balance) {                  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(sellPrice).div(100); // нужна дополнительная проверка, на случай повторного запроса при пустых резервах банка
            ethersAmount = this.balance;
        } else {
            tokensAmount = _amount;
        }
        if (!isRateActual()) {                   // проверяем курс на актуальность
            libreToken.burn(msg.sender, tokensAmount); // уменьшаем баланс клиента (в случае отмены ордера, токены клиенту возвращаются)
            orders.push(OrderData(false,msg.sender,tokensAmount,now)); // ставим ордер в очередь // msg.sender тут подходит? - Дима
            updateRate(); //                     и выходим из функции
            }
        // либо send, либо transfer исключение выдаст. посмотреть потом, можно ли transfer ограничиться
        if (msg.sender.transfer(ethersAmount)) {   
            libreToken.burn(msg.sender, tokensAmount);                                        
        } 
        LogSell(msg.sender, tokensAmount, ethersAmount, sellPrice);
    }

    function sellAfter (uint256 orderID) internal {
        address benificiar = orders[orderID].clientAddress;
        uint256 tokensAmount = orders[orderID].orderAmount;
        uint256 ethersAmount = tokensAmount.div(sellPrice).mul(100);
        if (ethersAmount > this.balance) {                  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(sellPrice).div(100); 
            libreToken.mint(benificiar, orders[orderID].orderAmount.sub(tokensAmount));
            ethersAmount = this.balance;
        } else {
            tokensAmount = orders[orderID].orderAmount;
            ethersAmount = tokensAmount.div(sellPrice).mul(100);
        }
        if (!benificiar.send(ethersAmount)) { 
            libreToken.mint(benificiar, tokensAmount);
            throw;                                         
        } 
        LogSell(benificiar, tokensAmount, ethersAmount, sellPrice);
    }

    function clearOrders () internal {
        uint ordersLength = orders.length;
        for (uint i = 0; i < ordersLength; i++) {
            if (orders[i].isBuy) {
                buyAfter (i); 
            } else {sellAfter (i);}
        }
        for (i = 0; i < ordersLength; i++) {
            delete orders[0];
        }
    }
}


