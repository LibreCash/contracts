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

    // Извещения о критических ситуациях
    /*
а) Резкое падение обеспечение
б) Значительный рост волатильности
в) Значительные различия между оракулами
г) Несколько неудачных попыток достучаться до оракулов
д) Снижение числа доступных оракулов меньше чем до №
    */
    event ReservesAlert (string description, uint BankBalance, uint TokensSupply);
    event VolatilityAlert (string description);
    event OraculusDivergenceAlert (string description);
    event LowOraclesNumberAlert (string description);



    address tokenAddress;
    token libreToken;


    //bool bankAllowTests = false; // для тестов тоже



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


     /**
     * @dev Gets min buy limit in tokens.
     */
    function getMinimumBuyTokens() public view returns (uint256) {
        return getLimitValue(limitType.minTokensBuy);
    }

     /**
     * @dev Gets max buy limit in tokens.
     */
    function getMaximumBuyTokens() public view returns (uint256) {
        return getLimitValue(limitType.maxTokensBuy);
    }

     /**
     * @dev Gets min sell limit in tokens.
     */
    function getMinimumSellTokens() public view returns (uint256) {
        return getLimitValue(limitType.minTokensSell);
    }

     /**
     * @dev Gets max sell limit in tokens.
     */
   function getMaximumSellTokens() public view returns (uint256) {
        return getLimitValue(limitType.maxTokensSell);
    }

    function BasicBank() public {
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
        //buyTokens(msg.sender);
    }

    /**
     * @dev Creates buy order.
     * @param _address Beneficiar.
     */
    function createBuyOrder(address _address) payable public {
        uint256 tokenCount = msg.value.mul(cryptoFiatRateBuy);
        require((tokenCount > getMinimumBuyTokens()) && (tokenCount < getMaximumBuyTokens()));
        orders.push(OrderData(OrderType.ORDER_BUY, _address, msg.value, now));
        OrderCreated("Buy", tokenCount, msg.value, cryptoFiatRateBuy);
    }

    /**
     * @dev Creates sell order.
     * @param _address Beneficiar.
     * @param _tokensCount Amount of tokens to sell.
     */
    function createSellOrder(address _address, uint256 _tokensCount) public {
        require((_tokensCount > getMinimumBuyTokens()) && (_tokensCount < getMaximumSellTokens()));
        orders.push(OrderData(OrderType.ORDER_BUY, _address, _tokensCount, now));
        OrderCreated("Sell", _tokensCount, 0, cryptoFiatRateSell); // пока заранее не считаем эфиры на вывод
    }


    /**
     * @dev Fills buy order from queue.
     * @param _orderID The order ID.
     */
    function fillBuyOrder(uint256 _orderID) internal returns (bool) {
/*        if (!isRateActual()) {
            return false;
        }*/
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

}