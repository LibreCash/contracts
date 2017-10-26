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
    event OrderCreated(string _type, uint256 tokens, uint256 crypto, uint256 rate);
    event LogBuy(address clientAddress, uint256 tokenAmount, uint256 cryptoAmount, uint256 buyPrice);
    event LogSell(address clientAddress, uint256 tokenAmount, uint256 cryptoAmount, uint256 sellPrice);

    address tokenAddress;
    token libreToken;

    //bool bankAllowTests = false; // для тестов
    

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOracles() {
     for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]] == msg.sender) {
            return true; 
            }
      }
    return false;
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

    function BasicBank() public {
        setBuyTokenLimits(0,0);
        setSellTokenLimits(0,0);
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
     * @dev Creates buy order.
     * @param _address Beneficiar.
     */
    function createBuyOrder(address _address) payable public {
        require((msg.value > getMinimumBuyTokens()) && (msg.value < getMaximumBuyTokens()));
        if (orders.length == 0) {
            requestUpdateRates();
        }
        orders.push(OrderData(OrderType.ORDER_BUY, _address, msg.value, now));
        OrderCreated("Buy", tokenCount, msg.value, cryptoFiatRateBuy);
    }

    /**
     * @dev Creates sell order.
     * @param _address Beneficiar.
     * @param _tokensCount Amount of tokens to sell.
     */
    function createSellOrder(address _address, uint256 _tokensCount) public {
        require((_tokensCount > getMinimumSellTokens()) && (_tokensCount < getMaximumSellTokens()));
        if (orders.length == 0) {
            requestUpdateRates();
        }
        orders.push(OrderData(OrderType.ORDER_BUY, _address, _tokensCount, now));
        OrderCreated("Sell", _tokensCount, 0, cryptoFiatRateSell); // пока заранее не считаем эфиры на вывод
    }

    /**
     * @dev Fills buy order from queue.
     * @param _orderID The order ID.
     */
    function fillBuyOrder(uint256 _orderID) internal returns (bool) {
        uint256 cryptoAmount = orders[_orderID].orderAmount;
        uint256 tokensAmount = cryptoAmount.mul(cryptoFiatRateBuy).div(100);
        address benificiar = orders[_orderID].clientAddress;  
        libreToken.mint(benificiar, tokensAmount);
        LogBuy(benificiar, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
        return true;
    }
    
    /**
     * @dev Fills sell order from queue.
     * @param _orderID The order ID.
     */
    function fillSellOrder(uint256 _orderID) internal returns (bool) {
        address beneficiar = orders[_orderID].clientAddress;
        uint256 tokensAmount = orders[_orderID].orderAmount;
        uint256 cryptoAmount = tokensAmount.div(cryptoFiatRateBuy).mul(100);
        if (this.balance < cryptoAmount) {  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(cryptoFiatRateBuy).div(100); 
            libreToken.mint(beneficiar, orders[_orderID].orderAmount.sub(tokensAmount));
            cryptoAmount = this.balance;
        } else {
            tokensAmount = orders[_orderID].orderAmount;
            cryptoAmount = tokensAmount.div(cryptoFiatRateBuy).mul(100);
        }
        if (!beneficiar.send(cryptoAmount)) { 
            libreToken.mint(beneficiar, tokensAmount); // so as burned at sellTokens
            return false;                                         
        } 
        LogSell(beneficiar, tokensAmount, cryptoAmount, cryptoFiatRateBuy);
        return true;
    }

    uint256 bottomOrderIndex = 0; // поднять потом наверх

    /**
     * @dev Fills order queue.
     */
    function fillOrders() internal returns (bool) {
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

    
    // про видимость подумать
    /**
     * @dev Touches oracles asking them to get new rates.
     */
    function requestUpdateRates() internal {
        require (numEnabledOracles >= MIN_ENABLED_ORACLES);
        numWaitingOracles = 0;
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].enabled) {
                oracleInterface(oracleAddresses[i]).updateRate();
                OracleTouched(oracleAddresses[i], oracles[oracleAddresses[i]].name);
                oracles[oracleAddresses[i]].waiting = true;
                numWaitingOracles++;
            }
            timeUpdateRequested = now;
        } // foreach oracles
        OraclesTouched("Запущено обновление курсов");
    }

    // подумать над видимостью
    /**
     * @dev Calculates crypto/fiat rate from "oracles" array.
     */
    function calculateRate() internal {
        require (numWaitingOracles <= MIN_WAITING_ORACLES);
        require (numEnabledOracles-numWaitingOracles >= MIN_ENABLED_NOT_WAITING_ORACLES);

        uint256 numReadyOracles = 0;
        uint256 sumRating = 0;
        uint256 integratedRates = 0;
        // the average rate would be: (sum of rating*rate)/(sum of ratings)
        // so the more rating oracle has, the more powerful his rate is
        for (uint i = 0; i < oracleAddresses.length; i++) {
            OracleData storage currentOracleData = oracles[oracleAddresses[i]];
            if (now <= currentOracleData.updateTime + 3 minutes) { // защита от флуда обновлениями, потом мб уберём
                if (currentOracleData.enabled) {
                    numReadyOracles++;
                    sumRating += currentOracleData.rating;
                    integratedRates += currentOracleData.rating.mul(currentOracleData.cryptoFiatRate);
                }
            }
        }
        require (numReadyOracles >= MIN_READY_ORACLES);

        uint256 finalRate = integratedRates.div(sumRating); // the formula is in upper comment
        setCurrencyRate(finalRate);
    }

    /**
     * @dev The callback from oracles.
     * @param _address The oracle address.
     * @param _rate The oracle ETH/USD rate.
     * @param _time Update time sent from oracle.
     */
    function oraclesCallback(address _address, uint256 _rate, uint256 _time) public onlyOracles {
        OracleCallback(_address, oracles[_address].name, _rate);
        if (!oracles[_address].waiting) {
-            TextLog("Oracle not waiting");
-        } else {
        // all ok, we waited for it
        numWaitingOracles--;
        // maybe we should check for existance of structure oracles[_address]? to think about it
        oracles[_address].cryptoFiatRate = _rate;
        oracles[_address].updateTime = _time;
        oracles[_address].waiting = false;
        if (numWaitingOracles == 0) {
                calculateRate();
                fillOrders();
        }
        }
    }

}