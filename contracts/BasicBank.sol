pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/lifecycle/Pausable.sol";

interface token {
    function balanceOf(address _owner) public returns (uint256);
    function mint(address _to, uint256 _amount) public;
    function getTokensAmount() public returns(uint256);
    function burn(address _burner, uint256 _value) public;
    function setBankAddress(address _bankAddress) public;
}

interface oracleInterface {
    function updateRate() payable public;
    function getName() constant public returns (bytes32);
    function setBank(address _bankAddress) public;
    function hasReceivedRate() public returns (bool);
}

/**
 * @title BasicBank.
 *
 * @dev Bank contract.
 */
contract BasicBank is Ownable, Pausable {
    using SafeMath for uint256;
    event InsufficientOracleData(string description, uint256 oracleCount);
    event OraclizeStatus(address indexed _address, bytes32 oraclesName, string description);
    event OracleAdded(address indexed _address, bytes32 name);
    event OracleEnabled(address indexed _address, bytes32 name);
    event OracleDisabled(address indexed _address, bytes32 name);
    event OracleDeleted(address indexed _address, bytes32 name);
    event OracleTouched(address indexed _address, bytes32 name);
    event OracleCallback(address indexed _address, bytes32 name, uint256 result);
    event TokensBought(address _beneficiar, uint256 tokensAmount, uint256 cryptoAmount);
    event TokensSold(address _beneficiar, uint256 tokensAmount, uint256 cryptoAmount);
    event UINTLog(uint256 data);
    event TextLog(string data);


    // пока на все случаи возможные
    uint256 constant MIN_ENABLED_ORACLES = 0; //2;
    uint256 constant MIN_WAITING_ORACLES = 0; //2;
    uint256 constant MIN_READY_ORACLES = 1; //2;
    uint256 constant MIN_ENABLED_NOT_WAITING_ORACLES = 1; //2;
    uint constant MAX_ORACLE_RATING = 10000;

    address tokenAddress;
    token libreToken;


    //bool bankAllowTests = false; // для тестов тоже
    uint256 public numWaitingOracles;
    uint256 public numEnabledOracles;
    uint256 public currencyUpdateTime;

    uint256 public cryptoFiatRate;
    uint256 public cryptoFiatRateSell;
    uint256 public cryptoFiatRateBuy;

    // maybe we should add weightWaitingOracles - sum of rating of waiting oracles
    uint256 timeUpdateRequested;

    enum limitType { minFiatRate, maxFiatRate, minTokensBuy, minTokensSell, maxTokensBuy, maxTokensSell }
    mapping (uint => uint256) limits;

    uint256 public sellFee = 10000;
    uint256 public buyFee = 10000;
    uint256 public sellSpread = 500 finney;
    uint256 public buySpread = 500 finney;

//    uint256 rate = 0;

    struct OracleData {
        bytes32 name;
        uint256 rating;
        bool enabled;
        bool waiting;
        uint256 updateTime; // time of callback
        uint256 cryptoFiatRate; // exchange rate
        uint listPointer; // чтобы знать по какому индексу удалять из массива oracleAddresses
    }
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

    mapping (address=>OracleData) oracles;
    address[] oracleAddresses;


    /**
     * @dev Sets buying eee.
     * @param _fee The fee in percent (100% = 10000).
     */
    function setBuyFee(uint256 _fee) public {
        require (_fee < 300000); // fee less than 300%
        buyFee = _fee;
    }

    /**
     * @dev Sets selling eee.
     * @param _fee The fee in percent (100% = 10000).
     */
    function setSellFee(uint256 _fee) public {
        require (_fee < 300000); // fee less than 300%
        sellFee = _fee;
    }

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
     * @dev Sets fiat rate limits.
     * @param _min Min rate.
     * @param _max Max rate.
     */
    function setRateLimits(uint256 _min, uint256 _max) public /*onlyOwner*/ {
        setLimitValue(limitType.minFiatRate, _min);
        setLimitValue(limitType.maxFiatRate, _max);
    }

    /**
     * @dev Sets fiat rate limits via range.
     * @param _percent Value in percent in both directions (100% = 10000).
     */
    function setRateRange(uint256 _percent) public {
        require (cryptoFiatRate > 0);
        require ((_percent < 10000) && (_percent > 0));
        uint256 _min = cryptoFiatRate.mul(10000 - _percent).div(10000);
        uint256 _max = cryptoFiatRate.mul(10000 + _percent).div(10000);
        setRateLimits(_min, _max);
    }

    /**
     * @dev Sets min/max buy limits.
     * @param _min Min limit.
     * @param _max Max limit.
     */
    function setBuyTokenLimits(uint256 _min, uint256 _max) public /*onlyOwner*/ {
        setLimitValue(limitType.minTokensBuy, _min);
        setLimitValue(limitType.maxTokensBuy, _max);
    }

    /**
     * @dev Sets min/max sell limits.
     * @param _min Min limit.
     * @param _max Max limit.
     */
    function setSellTokenLimits(uint256 _min, uint256 _max) public /*onlyOwner*/ {
        setLimitValue(limitType.minTokensSell, _min);
        setLimitValue(limitType.maxTokensSell, _max);
    }

    function getMinimumFiatRate() public view returns (uint256) {
        return getLimitValue(limitType.minFiatRate);
    }

    function getMaximumFiatRate() public view returns (uint256) {
        return getLimitValue(limitType.maxFiatRate);
    }

    function getMinimumBuyTokens() public view returns (uint256) {
        return getLimitValue(limitType.minTokensBuy);
    }

    function getMaximumBuyTokens() public view returns (uint256) {
        return getLimitValue(limitType.maxTokensBuy);
    }

    function getMinimumSellTokens() public view returns (uint256) {
        return getLimitValue(limitType.minTokensSell);
    }

    function getMaximumSellTokens() public view returns (uint256) {
        return getLimitValue(limitType.maxTokensSell);
    }

    function BasicBank() public {
    }

    /**
     * @dev Gets oracle count.
     */
    function getOracleCount() public view returns (uint) {
        return oracleAddresses.length;
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Adds an oracle.
     * @param _address The oracle address.
     */
    function addOracle(address _address) public {
        require(_address != 0x0);
        oracleInterface currentOracleInterface = oracleInterface(_address);
        // TODO: возможно нам не нужно обращаться к оракулу лишний раз
        // только чтобы имя получить?
        // возможно, стоит добавить параметр name в функцию, тем самым упростив всё
        bytes32 oracleName = currentOracleInterface.getName();
        OracleData memory thisOracle = OracleData({name: oracleName, rating: MAX_ORACLE_RATING.div(2), 
                                                    enabled: true, waiting: false, updateTime: 0, cryptoFiatRate: 0, listPointer: 0});
        oracles[_address] = thisOracle;
        // listPointer - индекс массива oracleAddresses с адресом оракула. Надо для удаления
        oracles[_address].listPointer = oracleAddresses.push(_address) - 1;
        currentOracleInterface.setBank(address(this));
        numEnabledOracles++;
        OracleAdded(_address, oracleName);
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Disable oracle.
     * @param _address The oracle address.
     */
    function disableOracle(address _address) public {
        oracles[_address].enabled = false;
        OracleDisabled(_address, oracles[_address].name);
        if (numEnabledOracles!=0) {
            numEnabledOracles--;
        }
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Enable oracle.
     * @param _address The oracle address.
     */
    function enableOracle(address _address) public {
        oracles[_address].enabled = true;
        OracleEnabled(_address, oracles[_address].name);
        numEnabledOracles++;
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Delete oracle.
     * @param _address The oracle address.
     */
    function deleteOracle(address _address) public {
        OracleDeleted(_address, oracles[_address].name);
        // может быть не стоит удалять ждущие? обсудить - Дима
        if (oracles[_address].waiting) {
            numWaitingOracles--;
        }
        if (oracles[_address].enabled) {
            numEnabledOracles--;
        }
        // так. из мэппинга оракулов по адресу получаем индекс в массиве оракулов с адресом оракула
        uint indexToDelete = oracles[_address].listPointer;
        // теперь получаем адрес последнего оракула из массива адресов
        address keyToMove = oracleAddresses[oracleAddresses.length - 1];
        // перезаписываем удаляемый оракул последним (в массиве адресов)
        oracleAddresses[indexToDelete] = keyToMove;
        // а в мэппинге удалим
        delete oracles[_address];
        // у бывшего последнего оракула из массива адресов теперь новый индекс в массиве
        oracles[keyToMove].listPointer = indexToDelete;
        // уменьшаем длину массива адресов, адрес в конце уже на месте удалённого стоит и нам не нужен
        oracleAddresses.length--;
    }

    /**
     * @dev Gets oracle name.
     * @param _address The oracle address.
     */
    function getOracleName(address _address) public view returns(bytes32) {
        return oracles[_address].name;
    }
    
    /**
     * @dev Gets oracle rating.
     * @param _address The oracle address.
     */
    function getOracleRating(address _address) public view returns(uint256) {
        return oracles[_address].rating;
    }

    /**
     * @dev Gets oracle rate.
     * @param _address The oracle address.
     */
    function getOracleRate(address _address) public view returns(uint256) {
        return oracles[_address].cryptoFiatRate;
    }

    /**
     * @dev Sets currency rate and updates timestamp.
     */
    function setCurrencyRate(uint256 _rate) internal {
//        bool validRate = (_rate > getLimitValue(limitType.minUsdRate)) && (_rate < getLimitValue(limitType.maxUsdRate));
//        require(validRate);
        cryptoFiatRate = _rate;
        currencyUpdateTime = now;
        cryptoFiatRateSell = _rate + sellSpread.mul(sellFee).div(10000);
        cryptoFiatRateBuy = _rate - buySpread.mul(buyFee).div(10000);
    }

    /**
     * @dev Funds each oracle till its balance is 0.2 eth (TODO: make a var for 0.2 eth).
     */
    function fundOracles() public payable {
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            UINTLog(oracleAddresses[i].balance);
            /* 200 finney = 0.2 ether */
            if (oracleAddresses[i].balance < 200 finney) {
               oracleAddresses[i].transfer(200 finney - oracleAddresses[i].balance);
            }
        } // foreach oracles
    }

    // про видимость подумать
    /**
     * @dev Touches oracles asking them to get new rates.
     */
    function requestUpdateRates() public payable returns (bool) {
        if (numEnabledOracles <= MIN_ENABLED_ORACLES) {
            InsufficientOracleData("Not enough enabled oracles to request updating rates", numEnabledOracles);
            return false;
        } // 1-2 enabled oracles - false result. we need more oracles. But anyway requests sent
        // numWaitingOracles goes -1 after each callback
        numWaitingOracles = 0;
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].enabled) {
                oracleInterface(oracleAddresses[i]).updateRate();
                OracleTouched(oracleAddresses[i], oracles[oracleAddresses[i]].name);
                oracles[oracleAddresses[i]].waiting = true;
                numWaitingOracles++;
            }
            timeUpdateRequested = now;
            // but we can not refer to return (i don't do throw here because update() already sent) - think about number of needed oracles
        } // foreach oracles
        return true;
    }

    // подумать над видимостью
    /**
     * @dev Calculates crypto/fiat rate from "oracles" array.
     */
    function getRate() public returns (bool) {
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
        uint256 sumRating = 0;
        uint256 integratedRates = 0;
        // the average rate would be: (sum of rating*rate)/(sum of ratings)
        // so the more rating oracle has, the more powerful his rate is
        for (uint i = 0; i < oracleAddresses.length; i++) {
            OracleData storage currentOracleData = oracles[oracleAddresses[i]];
        //    if (now <= currentOracle.updateTime + 5 minutes) { //up to date
                if (currentOracleData.enabled) {
                    numReadyOracles++;
                    // values for calculating the rate
                    sumRating += currentOracleData.rating;
                    integratedRates += currentOracleData.rating.mul(currentOracleData.cryptoFiatRate);
                }
        //    } else { // oracle's rate is older than 5 mins
        //        // just nothing? we don't increment readyOracles
        //    } // if old data
        } // foreach oracles
        if (numReadyOracles < MIN_READY_ORACLES) {
            InsufficientOracleData("Not enough not outdated oracles.", numReadyOracles);
            return false;
        } // maybe change/add rating of oracles
        if ((numReadyOracles != 0) && (numEnabledOracles.div(numReadyOracles) > 2)) {
            InsufficientOracleData("Ready oracles are less than 50% of all enabled oracles.", numReadyOracles);
            return false;
        } // numReadyOracles!=0 is already; need more than or equal to 50% ready oracles
        // here we can count the rate and return true
        //UINTLog(integratedRates);
        //UINTLog(sumRating);
        uint256 finalRate = integratedRates.div(sumRating); // formula is in upper comment
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
            TextLog("Oracle not waiting");
            // we didn't wait for this oracul
            // to do - think what to do, this information is useful, but why it is late or not wanted?
        } else {
            OracleCallback(_address, oracles[_address].name, _rate);
            // all ok, we waited for it
            numWaitingOracles--;
            // maybe we should check for existance of structure oracles[_address]? to think about it
            oracles[_address].cryptoFiatRate = _rate;
            oracles[_address].updateTime = _time;
            oracles[_address].waiting = false;
            // we don't need to update oracle name, so?
            // so i deleted 'string name' from func's arguments
            //getRate(); // returns true or false, maybe we will want check it later
        }
    }

    /**
     * @dev Attaches token contract.
     * @param _tokenAddress The token address.
     */
    function attachToken(address _tokenAddress) public {
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
    function totalTokenCount() public returns (uint256) {
        return libreToken.getTokensAmount();
    }

    /**
     * @dev Transfers crypto.
     */
   function withdrawCrypto(address _beneficiar) public {
        _beneficiar.transfer(this.balance);
    }

    function () payable external {
        buyTokens(msg.sender);
    }

    /**
     * @dev Creates buy order.
     * @param _address Beneficiar.
     */
    function createBuyOrder(address _address) payable public {
        require((msg.value > getMinimumBuyTokens()) && (msg.value < getMaximumBuyTokens()));
        orders.push(OrderData(OrderType.ORDER_BUY, _address, msg.value, now));
    }

    /**
     * @dev Creates sell order.
     * @param _address Beneficiar.
     * @param _tokensCount Amount of tokens to sell.
     */
    function createSellOrder(address _address, uint256 _tokensCount) public {
        orders.push(OrderData(OrderType.ORDER_BUY, _address, _tokensCount, now));
    }

    // удалю потом две нижние функции, будет общее разгребание очереди
    /**
     * @dev Lets user buy tokens.
     * @param _beneficiar The buyer's address.
     */
    function buyTokens(address _beneficiar) payable public {
/*        require(_beneficiar != 0x0);
        uint256 tokensAmount = msg.value.mul(cryptoFiatRate).div(100);  
        libreToken.mint(_beneficiar, tokensAmount);
        TokensBought(_beneficiar, tokensAmount, msg.value);*/
    }

    /**
     * @dev Lets user sell tokens.
     * @param _amount The amount of tokens.
     */
    function sellTokens(uint256 _amount) public {
/*        require (libreToken.balanceOf(msg.sender) >= _amount);        // checks if the sender has enough to sell
        
        uint256 tokensAmount;
        uint256 cryptoAmount = _amount.div(cryptoFiatRate).mul(100);
        if (cryptoAmount > this.balance) {                  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(cryptoFiatRate).div(100); // нужна дополнительная проверка, на случай повторного запроса при пустых резервах банка
            cryptoAmount = this.balance;
        } else {
            tokensAmount = _amount;
        }
        msg.sender.transfer(cryptoAmount);
        libreToken.burn(msg.sender, tokensAmount); 
        TokensSold(msg.sender, tokensAmount, cryptoAmount);
    }*/
}