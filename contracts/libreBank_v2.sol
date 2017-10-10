pragma solidity ^0.4.10;

import "./zeppelin/lifecycle/Pausable.sol";
import "./zeppelin/math/SafeMath.sol";


interface token {
    /*function transfer(address receiver, uint amount);*/
    function balanceOf(address _owner) returns (uint256);
    function mint(address _to,uint256 _amount);
    function getTokensAmount() public returns(uint256);
}

interface oracleInterface {
    function update();
    function getName() constant returns(string);
}

contract libreBank is Ownable,Pausable {
    using SafeMath for uint256;
    
    enum limitType { minUsdRate, maxUsdRate, minTransactionAmount, minSellSpread, maxSellSpread, minBuySpread, maxBuySpread }
    event newPriceTicker(string oracleName, string price);

    /*
    event LogSell(address Client, uint256 sendTokenAmount, uint256 EtherAmount, uint256 totalSupply);
    event LogBuy(address Client, uint256 TokenAmount, uint256 sendEtherAmount, uint256 totalSupply);
    event LogWhithdrawal (uint256 EtherAmount, address addressTo, uint invertPercentage);
    */

    struct oracleData {
        string name;
        address oracleAddress; // Maybe replace it on mapping (see below)
        uint256 rating;
        bool enabled;
    }

    oracleData[] oracles;
    uint256 updateDataRequest;
    
    mapping (string=>address) oraclesAddress;

 
    uint256 public currencyUpdateTime;
    uint256 public ethUsdRate = 30000; // In $ cents
    //uint256 public BuyPrice; // In $ cents
    //uint256 public SellPrice; // In $ cents

    uint256[] limits;
    oracleInterface currentOracle;
    token libreToken;
    uint256 minTokenAmount = 1; // used in sellTokens(...)
    uint256 buyPrice;
    uint256 sellPrice;

    function setLimitValue(limitType limitName, uint256 value) internal {
        limits[uint(limitName)] = value;
    }

    function getLimitValue(limitType limitName )internal returns (uint256) {
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
        require(_buySpread > getLimitValue(limitType.minBuySpread) && _buySpread < getLimitValue(limitType.maxBuySpread));
        require(_sellSpread > getLimitValue(limitType.minSellSpread) && _sellSpread < getLimitValue(limitType.maxSellSpread));
        buySpread = _buySpread;
        sellSpread = _sellSpread;
    }

    function addOracle(address oracleAddress) onlyOwner {
        require(oracleAddress != 0x0);
        oracleInterface(oracleAddress);
        oracleData memory thisOracle = new oracleData(oracleInterface.getName(),oracleAddress,0,true);
        oracles.push(thisOracle);
    }
    function getOracleName(uint number) public constant returns(string) {
        return oracles[number].name;
    }
    
    // Ограничие на периодичность обновления курса - не чаще чем раз в 5 минут
    modifier needUpdate() {
        require(!isRateActual());
        _;
    }

    function isRateActual() public constant returns(bool) {
        return now <= currencyUpdateTime + 5 minutes;
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


    function setCurrencyRate(uint256 rate) onlyOwner {
        bool validRate = rate > 0 && rate < getLimitValue(limitType.maxUsdRate) && rate > getLimitValue(limitType.minUsdRate);
        require(validRate);
        ethUsdRate = rate;
        currencyUpdateTime = now;
    }

    function withdrawEther(address beneficiar) onlyOwner {
        beneficiar.send(this.balance);
    }


    function updateRate() needUpdate {
        ethUsdRate = getRate();
    }

    function getRate() private returns(bool) {
        uint256[] oracleResults;
        for (uint256 i = 0; i < oracles.length; i++) {
            if (oracles[i].enabled) oracleInterface(oracle[i].oracleAddress).update();
        }
        return true;
    }

    function oraclesCallback(string name,uint256 value,uint256 timestamp) {
        // Implement it later
         uint256 currentSpread = SafeMath.add(limits[limitType.minBuySpread], limits[limitType.minSellSpread]);
        uint256 halfSpread = SafeMath.div(currentSpread, 2);
        // require(halfSpread < currentSpread); // -- not sure if we need to check (possibly no), I need to research types and possible vulnerabilities - Dima
        // ethUsdRate now - base ecxhange rate in cents, so:
        buyPrice = SafeMath.sub(ethUsdRate, halfSpread);
        sellPrice = SafeMath.add(ethUsdRate, halfSpread);
         
       
    }

    // ***************************************************************************

    // Buy token by sending ether here
    //
    // Price is being determined by the algorithm in recalculatePrice()
    // You can also send the ether directly to the contract address   

    function () payable external {
        buyTokens(msg.sender);
    }

    function buyTokens () payable public {
        buyTokens(msg.sender);
    }

    function buyTokens(address benificiar) payable public {
        require(msg.value > getLimitValue(limitType.minTransactionAmount));
        
        uint256 tokensAmount;
        //if (!isRateActual) { //commented because updateRate's modifier already checks the necessity, but maybe should do some refactoring
            updateRate();
        //}
       
        tokensAmount = msg.value.mul(buyPrice).div(100); // maybe we can not use div(100) and make rate in dollars?
        libreToken.mint(benificiar, tokensAmount);
        // LogBuy(benificiar, msg.value, _amount, totalSupply);
    }

    function buyAfter {
        require(msg.value > getLimitValue(limitType.minTransactionAmount));
        uint256 buyPrice;
        uint256 tokensAmount;
        //if (!isRateActual) { //commented because updateRate's modifier already checks the necessity, but maybe should do some refactoring
            updateRate();
        //}
       
        // in case of possible overflows should do assert() or require() for sellPrice>ethUsdRate and buyPrice<..., but we need a small research
        tokensAmount = msg.value.mul(buyPrice).div(100); // maybe we can not use div(100) and make rate in dollars?
        libreToken.mint(benificiar, tokensAmount);
        // LogBuy(benificiar, msg.value, _amount, totalSupply);

    }
  
    function sellTokens(uint256 _amount) {
        require (msg.sender.balance >= _amount);        // checks if the sender has enough to sell
        // todo: make ERC20-like contract and use balanceOf(msg.sender)
        require (_amount >= minTokenAmount);
        uint256 sellPrice;
        uint256 tokensAmount;
        uint256 ethersAmount;
        //if (!isRateActual) { //commented because updateRate's modifier already checks the necessity, but maybe should do some refactoring
            updateRate();
        //}
       
        
        if (ethersAmount > this.balance) {                  // checks if the bank has enough Ethers to send
            // think about it: if this.balance is balanceOf(msg.sender)? if so, just use it because of ERC20
            tokensAmount = this.balance.mul(sellPrice).div(100);
            ethersAmount = this.balance;
        } else {
            tokensAmount = _amount;
            ethersAmount = _amount.div(sellPrice).mul(100);
        }
        // Dimon doesn't like next part and suggests some refactoring (:
        if (!_address.send(EthersAmount)) {   /*maybe this.send? think about it*/     // sends ether to the seller. It's important
            throw;                                         // to do this last to avoid recursion attacks
        } else { 
           libreToken.burn(msg.sender, tokensAmount);
        }
        //LogSell(_address, eokensAmount, ethersAmount, totalSupply);
    }

    function sellAfter {
        
    }
}


