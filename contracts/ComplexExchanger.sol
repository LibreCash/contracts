pragma solidity ^0.4.23;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/math/Math.sol';
import "./interfaces/I_Oracle.sol";
import "./interfaces/I_Exchanger.sol";
import "./token/LibreCash.sol";
import "./OracleFeed.sol";


contract ComplexExchanger is ExchangerI {
    using SafeMath for uint256;

    address public tokenAddress;
    LibreCash token;

    OracleFeed public feed;

    uint256 public deadline;
    address public withdrawWallet;

    uint256 public requestTime;
    uint256 public calcTime;

    uint256 public buyFee;
    uint256 public sellFee;

    uint256 constant FEE_MULTIPLIER = 100;
    uint256 constant RATE_MULTIPLIER = 1000;
    uint256 constant MAX_FEE = 70 * FEE_MULTIPLIER; // 70%

    event Buy(address sender, address recipient, uint256 tokenAmount, uint256 price);
    event Sell(address sender, address recipient, uint256 cryptoAmount, uint256 price);
    event ReserveRefill(uint256 amount);
    event ReserveWithdraw(uint256 amount);

    enum State {
        LOCKED,
        PROCESSING_ORDERS,
        WAIT_ORACLES,
        CALC_RATES,
        REQUEST_RATES
    }

    function() payable public {
        buyTokens(msg.sender);
    }

    constructor (
        address _token,
        uint256 _buyFee,
        uint256 _sellFee,
        address _feed,
        uint256 _deadline,
        address _withdrawWallet
    ) public
    {
        require(
            _withdrawWallet != address(0x0) &&
            _token != address(0x0) &&
            _deadline > now &&
            _feed != address(0x0) &&
            _buyFee <= MAX_FEE &&
            _sellFee <= MAX_FEE
        );

        tokenAddress = _token;
        token = LibreCash(tokenAddress);
        feed = OracleFeed(_feed);
        buyFee = _buyFee;
        sellFee = _sellFee;
        deadline = _deadline;
        withdrawWallet = _withdrawWallet;
    }

    /**
     * @dev Returns the contract/feed state.
     */
    function getState() public view returns (State) {
        if (now >= deadline)
            return State.LOCKED;
        return State(uint256(feed.getState()));
    }

    /**
     * @dev Returns buy rate.
     */
    function buyRate() public view returns (uint256) {
        return feed.buyRate().mul(100 * FEE_MULTIPLIER - buyFee) / 100 / FEE_MULTIPLIER;
    }

    /**
     * @dev Returns sell rate.
     */
    function sellRate() public view returns (uint256) {
        return feed.sellRate().mul(100 * FEE_MULTIPLIER + sellFee) / 100 / FEE_MULTIPLIER;
    }

    /**
     * @dev Allows user to buy tokens by ether.
     * @param _recipient The recipient of tokens.
     */
    function buyTokens(address _recipient) public payable {
        require(getState() == State.PROCESSING_ORDERS);

        uint256 _buyRate = buyRate();

        uint256 availableTokens = tokenBalance();
        require(availableTokens > 0);

        uint256 tokensAmount = msg.value.mul(_buyRate) / RATE_MULTIPLIER;
        require(tokensAmount != 0);

        uint256 refundAmount = 0;
        // if recipient set as 0x0 - recipient is sender
        address recipient = _recipient == 0x0 ? msg.sender : _recipient;

        if (tokensAmount > availableTokens) {
            refundAmount = tokensAmount.sub(availableTokens).mul(RATE_MULTIPLIER) / _buyRate;
            tokensAmount = availableTokens;
        }

        token.transfer(recipient, tokensAmount);
        emit Buy(msg.sender, recipient, tokensAmount, _buyRate);
        if (refundAmount > 0)
            recipient.transfer(refundAmount);
    }

    /**
     * @dev Allows user to sell tokens and get ether.
     * @param _recipient The recipient of ether.
     * @param tokensCount The count of tokens to sell.
     */
    function sellTokens(address _recipient, uint256 tokensCount) public {
        require(getState() == State.PROCESSING_ORDERS);
        require(tokensCount <= token.allowance(msg.sender, this));

        uint256 _sellRate = sellRate();

        uint256 cryptoAmount = tokensCount.mul(RATE_MULTIPLIER) / _sellRate;
        require(cryptoAmount != 0);

        if (cryptoAmount > address(this).balance) {
            uint256 extraTokens = (cryptoAmount - address(this).balance).mul(_sellRate) / RATE_MULTIPLIER;
            cryptoAmount = address(this).balance;
            tokensCount = tokensCount.sub(extraTokens);
        }

        token.transferFrom(msg.sender, this, tokensCount);
        address recipient = _recipient == 0x0 ? msg.sender : _recipient;

        emit Sell(msg.sender, recipient, cryptoAmount, _sellRate);
        recipient.transfer(cryptoAmount);
    }

    /**
     * @dev Returns token balance of the sender.
     */
    function tokenBalance() public view returns(uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @dev Withdraws balance only to special hardcoded wallet ONLY WHEN contract is locked.
     */
    function withdrawReserve() public {
        require(getState() == State.LOCKED && msg.sender == withdrawWallet);
        emit ReserveWithdraw(address(this).balance);
        token.transfer(withdrawWallet, tokenBalance());
        selfdestruct(withdrawWallet);
    }

    /**
     * @dev Allows to deposit eth to the contract without creating orders.
     */
    function refillBalance() public payable {
        emit ReserveRefill(msg.value);
    }
}
