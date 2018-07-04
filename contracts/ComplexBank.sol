pragma solidity ^0.4.23;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/math/Math.sol';
import './TimePause.sol';
import "./interfaces/I_Oracle.sol";
import "./interfaces/I_Bank.sol";
import "./token/LibreCash.sol";
import "./OracleFeed.sol";


contract ComplexBank is TimePause, BankI {
    using SafeMath for uint256;
    address public tokenAddress;
    LibreCash token;

    OracleFeed public feed;

    event Buy(address sender, address recipient, uint256 tokenAmount, uint256 price);
    event Sell(address sender, address recipient, uint256 cryptoAmount, uint256 price);

    uint256 constant public FEE_MULTIPLIER = 100;
    uint256 constant public RATE_MULTIPLIER = 1000; // doubling in oracleBase __callback as parseIntRound(..., 3) as 3

    enum State {
        LOCKED,
        PROCESSING_ORDERS,
        WAIT_ORACLES,
        CALC_RATES,
        REQUEST_RATES
    }

    modifier state(State needState) {
        require(getState() == needState);
        _;
    }

    constructor (address _token, uint256 _buyFee, uint256 _sellFee, address _feed)
        public
    {
        require(
            _buyFee <= MAX_FEE &&
            _sellFee <= MAX_FEE
        );
        tokenAddress = _token;
        token = LibreCash(tokenAddress);
        feed = OracleFeed(_feed);
        buyFee = _buyFee;
        sellFee = _sellFee;
    }

    /**
     * @dev get contract state.
     */
    function getState() public view returns (State) {
        if (paused())
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

    // 01-emission start

    /**
     * @dev Creates buy order.
     * @param _recipient Recipient.
     */
    function buyTokens(address _recipient)
        payable
        public
        whenNotPaused
        state(State.PROCESSING_ORDERS)
    {
        uint256 _buyRate = buyRate();
        uint256 tokensAmount = msg.value.mul(_buyRate) / RATE_MULTIPLIER;
        require(tokensAmount != 0);

        // if recipient set as 0x0 - recipient is sender
        address recipient = _recipient == 0x0 ? msg.sender : _recipient;

        token.mint(recipient, tokensAmount);
        emit Buy(msg.sender, recipient, tokensAmount, _buyRate);
    }

    /**
     * @dev Creates sell order.
     * @param _recipient Recipient.
     * @param tokensCount Amount of tokens to sell.
     */
    function sellTokens(address _recipient, uint256 tokensCount)
        public
        whenNotPaused
        state(State.PROCESSING_ORDERS)
    {
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
        token.burn(tokensCount);
        address recipient = _recipient == 0x0 ? msg.sender : _recipient;

        emit Sell(msg.sender, recipient, cryptoAmount, _sellRate);
        recipient.transfer(cryptoAmount);
    }

    /**
     * @dev Fallback function.
     */
    function() external payable {
        buyTokens(msg.sender);
    }

    // 01-emission end

    /**
     * @dev Attaches token contract.
     * @param _tokenAddress The token address.
     */
    function attachToken(address _tokenAddress) public onlyOwner {
        require(_tokenAddress != 0x0);
        tokenAddress = _tokenAddress;
        token = LibreCash(tokenAddress);
    }

    uint256 public buyFee = 0;
    uint256 public sellFee = 0;
    uint256 constant MAX_FEE = 70 * FEE_MULTIPLIER; // 70%

    /**
     * @dev Sets buyFee and sellFee.
     * @param _buyFee The buy fee.
     * @param _sellFee The sell fee.
     */
    function setFees(uint256 _buyFee, uint256 _sellFee) public onlyOwner {
        require(_buyFee <= MAX_FEE && _sellFee <= MAX_FEE);

        sellFee = _sellFee;
        buyFee = _buyFee;
    }

    // system methods start

    /**
     * @dev set new owner.
     * @param newOwner The new owner for token.
     */
    function transferTokenOwner(address newOwner) public onlyOwner {
        token.transferOwnership(newOwner);
    }

    /**
     * @dev Claims token ownership.
     */
    function claimOwnership() public onlyOwner {
        token.claimOwnership();
    }

    // TODO: Delete after tests. Used to withdraw balance in test network
    /**
     * @dev Withdraws all the balance to owner.
     */
    function withdrawBalance() public onlyOwner {
        owner.transfer(address(this).balance);
    }

    /**
     * @dev selfdectruct contract
     */
    function destruct() public onlyOwner {
        require(getState() == State.LOCKED);
        selfdestruct(owner);
    }
}
