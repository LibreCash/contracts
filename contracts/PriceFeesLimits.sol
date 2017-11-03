pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/ownership/Ownable.sol";

/**
 * @title PriceFeesLimits.
 *
 * @dev Contract.
 */
contract PriceFeesLimits is Ownable {
    using SafeMath for uint256;

    uint256 public currencyUpdateTime;

    uint256 public cryptoFiatRate;
    uint256 public cryptoFiatRateSell;
    uint256 public cryptoFiatRateBuy;

    struct Limit {
        uint256 min;
        uint256 max;
    }

    Limit limitCryptoFiatRate;
    Limit limitBuyOrder;
    Limit limitSellOrder;

    //enum limitType { minCryptoFiatRate, maxCryptoFiatRate, minTokensBuy, minTokensSell, maxTokensBuy, maxTokensSell }
    //mapping (uint => uint256) limits;

    uint256 public sellFee = 500; // 5%
    uint256 public buyFee = 500;

    uint256 constant MAX_UINT256 = 2**256 - 1;
    uint256 constant MAX_BUYFEE = 30000;
    uint256 constant MAX_SELLFEE = 30000;

    /**
     * @dev Sets fiat rate limits.
     * @param _min Min rate.
     * @param _max Max rate.
     */
    function setRateLimits(uint256 _min, uint256 _max) public onlyOwner {
        limitCryptoFiatRate.min = _min;
        limitCryptoFiatRate.max = _max;
    }

    /**
     * @dev Sets min/max buy limits.
     * @param _min Min limit.
     * @param _max Max limit.
     */
    function setBuyTokenLimits(uint256 _min, uint256 _max) public onlyOwner {
        limitBuyOrder.min = _min;
        limitBuyOrder.max = _max;
    }

    /**
     * @dev Sets min/max sell limits.
     * @param _min Min limit.
     * @param _max Max limit.
     */
    function setSellTokenLimits(uint256 _min, uint256 _max) public onlyOwner {
        limitSellOrder.min = _min;
        limitSellOrder.max = _max;
    }

    /**
     * @dev Gets buy limits in tokens.
     */
    function getBuyTokenLimits() public view returns (uint256, uint256) {
        return (limitBuyOrder.min, limitBuyOrder.max);
    }

    /**
     * @dev Gets sell limits in tokens.
     */
    function getSellTokenLimits() public view returns (uint256, uint256) {
        return (limitSellOrder.min, limitSellOrder.max);
    }

    /**
     * @dev Sets buying fee.
     * @param _fee The fee in percent (100% = 10000).
     */
    function setBuyFee(uint256 _fee) public onlyOwner {
        require (_fee < MAX_BUYFEE);
        buyFee = _fee;
    }

    /**
     * @dev Sets selling fee.
     * @param _fee The fee in percent (100% = 10000).
     */
    function setSellFee(uint256 _fee) public onlyOwner {
        require (_fee < MAX_SELLFEE);
        sellFee = _fee;
    }

    /**
     * @dev Gets min crypto fiat rate.
     */
    function getCryptoFiatRateLimits() public view returns (uint256, uint256) {
        return (limitCryptoFiatRate.min, limitCryptoFiatRate.max);
    }
}