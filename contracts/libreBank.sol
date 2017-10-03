pragma solidity ^0.4.10;

import "./zeppelin/lifecycle/Pausable.sol";
import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/math/SafeMath.sol";

interface token {
    /*function transfer(address receiver, uint amount);*/
    function balanceOf(address _owner) returns (uint256);
    function mint(address _to,uint256 _amount);
    function getTokensAmount() public returns(uint256);
}

contract libreBank is Ownable,Pausable {
    using SafeMath for uint256;
    
    enum limitType { minUsdRate, maxUsdRate, minTransactionAmount, minSpread, maxSpread }

    /*
    event newOraclizeQuery(string description);
    event newPriceTicker(string price);
    event LogSell(address Client, uint256 sendTokenAmount, uint256 EtherAmount, uint256 totalSupply);
    event LogBuy(address Client, uint256 TokenAmount, uint256 sendEtherAmount, uint256 totalSupply);
    event LogWhithdrawal (uint256 EtherAmount, address addressTo, uint invertPercentage);
    */


    uint256 public currencyUpdateTime;
    uint256 public ethUsdRate = 30000; // In $ cents
    uint256[] limits;
    token libreToken;

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

    function setSpreadLimits(uint256 minSpead, uint256 maxSpread) onlyOwner {
        setLimitValue(limitType.minSpread,minSpead);
        setLimitValue(limitType.maxSpread,maxSpread);
        
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

    function () payable {
        buyTokens(msg.sender);
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

    function getRate() returns(uint256) {
        // Not implemented yet
        return 280;
    }

    function buyTokens(address benificiar) {
        require(msg.value > getLimitValue(limitType.minTransactionAmount));

        uint256 tokensAmount = msg.value.mul(ethUsdRate).div(getTokenPrice());
        libreToken.mint(benificiar,tokensAmount);
    }
    // ! Not Impemented Yet
    function sellTokens() {}
}
