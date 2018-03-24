pragma solidity ^0.4.18;


import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/math/Math.sol";
import "./zeppelin/lifecycle/Pausable.sol";
import "./zeppelin/ownership/Ownable.sol";
import "./interfaces/I_Oracle.sol";
import "./interfaces/I_Bank.sol";
import "./token/LibreCash.sol";
import "./ComplexExchanger.sol";

contract Loans is Ownable {
    using SafeMath for uint256;
    address public Libre;
    address public Exchanger;
    mapping(address=>bool) oracles;

    mapping(address => uint256) public balance;

    uint256 public rateTime;
    uint256 public rate;
    uint256 public RATE_ACTUAL = 10 minutes;
    uint256 public requestTime;


    LibreCash token;
    ComplexExchanger exchanger;


    uint256 public fee = 200;
    uint256 public percent = 150;
    uint256 public constant REVERSE_PERCENT = 100;
    uint256 public constant RATE_MULTIPLIER = 1000;
    uint256 public requestCost = 0.0005 ether;

    struct Limit {
        uint256 min;
        uint256 max;
    }

    Limit public loanLimitEth = Limit(0, 100 ether);
    Limit public loanLimitLibre = Limit(0 wei, 100 ether);

    event NewLoan(Assets asset, uint256 timestamp, uint256 deadline, uint256 amount, uint256 margin, Status status);
    event OracleRequest();
    event OracleAdded(address oracle);
    event Ticker(uint256 rate);

    modifier onlyOracle {
        require(oracles[msg.sender]);
        _;
    }

    Loan[] loansLibre;
    Loan[] loansEth;

    enum Assets {
        libre,
        eth
    }

    enum Status {
        active,
        used,
        completed
    }

    struct Loan {
        address holder;
        address recipient;
        uint256 timestamp;
        uint256 period;
        uint256 amount;
        uint256 margin;
        uint256 pledge;
        Status status;
    }

    function Loans(address _libre, address _exchanger) public {
        require(_libre != 0x0 && _exchanger != 0x0);
        Libre = _libre; 
        Exchanger = _exchanger;
        token = LibreCash(Libre);
        exchanger = ComplexExchanger(Exchanger);
    }


    function getLoanLibre(uint256 id) public view returns(address,address,uint256,uint256,uint256,uint256,uint256,Status) {
        return getLoan(loansLibre,id, Assets.libre);
    }

    function getLoanEth(uint256 id) public view returns(address,address,uint256,uint256,uint256,uint256,uint256,Status) {
        return getLoan(loansEth, id, Assets.eth);
    }

    function getLoan(Loan[] loans,uint256 id, Assets asset) internal view returns(address,address,uint256,uint256,uint256,uint256,uint256,Status) {
        Loan memory loan = loans[id];
        uint256 refund = (asset == Assets.libre) ? refundAmountEth(loan.amount,loan.margin) : refundAmountLibre(loan.amount,loan.margin);
        return (
            loan.holder,
            loan.recipient,
            loan.timestamp,
            loan.period,
            loan.amount,
            loan.margin,
            refund,
            loan.status
        );
    }

    function createLoanLibre(uint256 _period, uint256 _amount, uint256 _margin) public {
        require(_amount >= loanLimitLibre.min && _amount <= loanLimitLibre.max);
        
        token.transferFrom(msg.sender,this,_amount);
        Loan memory curLoan = Loan(msg.sender,0x0,now,_period,_amount, _margin,0,Status.active);
        loansLibre.push(curLoan);

        NewLoan(Assets.eth, now, _period, _amount, _margin, Status.active);
    }

    function createLoanEth(uint256 _period, uint256 _amount, uint256 _margin) payable public {
        require(_amount <= msg.value &&_amount >= loanLimitEth.min && _amount <= loanLimitEth.max);
        
        uint256 refund = msg.value.sub(_amount);
        
        Loan memory curLoan = Loan(msg.sender, 0x0, now, _period, msg.value, _margin, 0, Status.active);
        
        loansEth.push(curLoan);
        
        NewLoan(Assets.libre,now, _period, _amount, _margin, Status.active);

        if(refund > 0)
            msg.sender.transfer(refund);

    }

    function cancelLoanEth(uint256 id) public {
        Loan memory loan = loansEth[id];
        require(
            loan.holder == msg.sender && 
            loan.recipient == 0x0 && 
            loan.status == Status.active
        );
        address holder = loansEth[id].holder;

        loansEth[id].holder = 0x0;
        loansEth[id].status = Status.completed;
        holder.transfer(loan.amount);
    }


    function cancelLoanLibre(uint256 id) public {
        Loan memory loan = loansLibre[id];
        require(
            loan.holder == msg.sender && 
            loan.recipient == 0x0 && 
            loan.status == Status.active
        );
        address holder = loansEth[id].holder;

        loansEth[id].holder = 0x0;
        loansEth[id].status = Status.completed;

        token.transfer(holder,loan.amount);
    }

    function backEth(uint256 id) public payable {
        Loan memory loan = loansEth[id];
        uint256 needSend = loan.amount.add(loan.margin);

        require (
            loan.holder != 0x0 &&
            msg.sender == loan.recipient &&
            msg.value >= needSend
        );

        balance[loan.holder] = balance[loan.holder].add(needSend);
        token.transfer(msg.sender, loan.pledge);

        if (msg.value > needSend)
            msg.sender.transfer(msg.value - needSend);

        loansEth[id].holder = 0x0;
    }

    function backLibre(uint256 id) public {
        Loan memory loan = loansLibre[id];
        uint256 needBack = loan.amount.add(loan.margin);


        require (
            loan.holder != 0x0 &&
            msg.sender == loan.recipient
        );

        token.transferFrom(msg.sender, this, needBack);
        token.transfer(loan.holder, needBack);
        balance[loan.recipient] = balance[loan.recipient].add(loan.pledge);

        loansLibre[id].holder = 0x0;
    }

    function closeLoanEth(uint256 id) public {
        Loan memory loan = loansEth[id];

        require (
            msg.sender == loan.holder &&
            now > (loan.timestamp + loan.period) &&
            exchanger.getState() == ComplexExchanger.State.PROCESSING_ORDERS
        );

        uint256 rate = exchanger.sellRate();
        uint256 needReturn = loan.amount.add(loan.margin);
        uint256 havePledge = loan.pledge.mul(RATE_MULTIPLIER) / rate;

        if (havePledge < needReturn)
          needReturn = havePledge;

        uint256 sellTokens = needReturn * rate / RATE_MULTIPLIER;

        token.approve(Exchanger,sellTokens);
        exchanger.sellTokens(loan.holder,sellTokens);

        loansEth[id].holder = 0x0;
    }
    

    function closeLoanLibre(uint256 id) public {
        Loan memory loan = loansLibre[id];


        require (
            msg.sender == loan.holder &&
            now > (loan.timestamp + loan.period) &&
            exchanger.getState() == ComplexExchanger.State.PROCESSING_ORDERS
        );
        
        uint256 rate = exchanger.buyRate();
        uint256 needReturn = loan.amount.add(loan.margin);
        uint256 havePledge = loan.pledge * rate / RATE_MULTIPLIER;

        if (havePledge < needReturn)
          needReturn = havePledge;

        uint256 buyTokens = needReturn.mul(RATE_MULTIPLIER) / rate;
        exchanger.buyTokens.value(buyTokens)(loan.holder);

        loansLibre[id].holder = 0x0;
    }


    /**
     * @dev Returns loans count (Libre, Eth)
     */
    function loansCount() public view returns(uint256,uint256) {
        return (loansLibre.length,loansEth.length);
    }

    function getLoans(uint256 _page, uint256 _pageCount, uint8 _type) public view returns (uint256[], uint256) {
        uint256 firstOrder = _page * _pageCount;
        uint256 lastOrder = firstOrder + _pageCount;
        // 1 - eth, 0 - libre (check?)
        Loan[] memory loans = (_type == 1) ? loansEth : loansLibre;
        uint256[] memory orders = new uint256[](_pageCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < loans.length; i++) {
            bool _active = (loans[i].status == Status.active);
            if (_active) {
                counter++;
            }
            if (counter - 1 < firstOrder) continue;
            if (counter - 1 > lastOrder - 1) continue;
            if (_active) {
                orders[counter - firstOrder - 1] = i;
            }
        }
        return (orders, counter);
    }

    // method only for tests
    function fillTestLoans() public {
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.used));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.completed));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.used));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));   
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.completed));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.used));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 100, 0, Status.active));   

        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.used));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.used));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.active));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.completed));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.used));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.used));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.active));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.active));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.active));        
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.used));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.active));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.active));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 555, 0, Status.active));        
    }

    function tokenBalance() public view  returns(uint256) {
        return token.balanceOf(this);
    }

    function isRateActual() public view returns(bool) {
        return now - rateTime < RATE_ACTUAL;
    }

    /**
     * @dev Allows contract owner to set loans fee.
     * @param _fee The fee percent
     */
    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function setPercent(uint256 _percent) public onlyOwner {
        percent = _percent;
    }

    function __callback(uint256 _rate) public onlyOracle {
        rate = _rate;
        rateTime = now;
    }   

    function addOracle(address oracle) public onlyOwner {
        require(!oracles[oracle]);
        oracles[oracle] = true;
        OracleAdded(oracle);
    }


    function requestRate() public payable {
        require(!isRateActual() && msg.value >= requestPrice() && (now - requestTime) > 10 minutes);
        requestTime = now;
        OracleRequest();
    }

    function requestPrice() public view returns(uint256) {
        return requestCost;
    }

    function refundAmountLibre(uint256 ethAmount, uint256 margin) public view returns(uint256) {
        // Implement percent and fee multiplication later
        return isRateActual() ? ethAmount.add(margin) : 0;
    }

    function refundAmountEth(uint256 libreAmount, uint256 margin) public view returns(uint256) {
        // Implement percent and fee multiplication later
        return isRateActual() ? libreAmount.add(margin) : 0;
    }
}