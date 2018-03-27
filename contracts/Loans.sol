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
    LibreCash token;
    ComplexExchanger exchanger;

    mapping(address => uint256) public balance;
    uint256 public feeLibre = 200;
    uint256 public feeEth = 200;
    uint256 public pledgePercent = 15000;
    uint256 public marginCallPercent = 13000;
    uint256 public constant PERCENT_MULTIPLIER = 100;
    uint256 public constant RATE_MULTIPLIER = 1000;

    struct Limit {
        uint256 min;
        uint256 max;
    }

    Limit public loanLimitEth = Limit(0, 10000 ether);
    Limit public loanLimitLibre = Limit(0 wei, 100000 ether);

    event NewLoan(Assets asset, uint256 timestamp, uint256 deadline, uint256 amount, uint256 margin, Status status);
    event OracleRequest();
    event OracleAdded(address oracle);
    event Ticker(uint256 rate);

    enum Assets {
        LIBRE,
        ETH
    }

    enum Status {
        ACTIVE,
        USED,
        COMPLETED
    }

    struct Loan {
        address holder;
        address recipient;
        uint256 timestamp;
        uint256 period;
        uint256 amount;
        uint256 margin;
        uint256 fee;
        uint256 pledge;
        Status status;
    }

    Loan[] loansLibre;
    Loan[] loansEth;

    function Loans(address _libre, address _exchanger) public {
        require(_libre != 0x0 && _exchanger != 0x0);
        Libre = _libre; 
        Exchanger = _exchanger;
        token = LibreCash(Libre);
        exchanger = ComplexExchanger(Exchanger);
    }


    function getLoanLibre(uint256 id) public view returns(address,address,uint256[6],Status) {
        return getLoan(Assets.LIBRE, loansLibre[id]);
    }

    function getLoanEth(uint256 id) public view returns(address,address,uint256[6],Status) {
        return getLoan(Assets.ETH, loansEth[id]);
    }

    function getLoan(Assets asset, Loan loan) internal view 
        returns(address,address,uint256[6],Status)
    {
        uint256[6] memory loanData = [
            loan.timestamp,
            loan.period,
            loan.amount,
            loan.margin,
            refundAmount(loan),
            calcPledge(asset,loan)
        ];

        return (
            loan.holder,
            loan.recipient,
            loanData,
            loan.status
        );
    }
    function calcPledge(Assets asset,Loan loan) internal returns(uint256) {
        return asset == Assets.LIBRE ? calcPledgeLibre(loan, pledgePercent) :
                            calcPledgeEth(loan, pledgePercent);
    }

    function giveLibre(uint256 _period, uint256 _amount, uint256 _margin) public {
        require(_amount >= loanLimitLibre.min && _amount <= loanLimitLibre.max);
        
        token.transferFrom(msg.sender,this,_amount);
        Loan memory curLoan = Loan(msg.sender, 0x0, now, _period, _amount, _margin, feeLibre, 0, Status.ACTIVE);
        loansLibre.push(curLoan);

        NewLoan(Assets.ETH, now, _period, _amount, _margin, Status.ACTIVE);
    }

    function giveEth(uint256 _period, uint256 _amount, uint256 _margin) payable public {
        require(_amount <= msg.value &&_amount >= loanLimitEth.min && _amount <= loanLimitEth.max);
        
        uint256 refund = msg.value.sub(_amount);
        
        Loan memory curLoan = Loan(msg.sender, 0x0, now, _period, _amount, _margin, feeEth, 0, Status.ACTIVE);
        
        loansEth.push(curLoan);
        
        NewLoan(Assets.LIBRE,now, _period, _amount, _margin, Status.ACTIVE);

        if(refund > 0)
            msg.sender.transfer(refund);

    }

    function cancelEth(uint256 id) public {
        Loan memory loan = loansEth[id];
        require(
            loan.holder == msg.sender &&
            loan.status == Status.ACTIVE
        );

        loansEth[id].status = Status.COMPLETED;
        loansEth[id].holder.transfer(loan.amount);
    }


    function cancelLibre(uint256 id) public {
        Loan memory loan = loansLibre[id];
        require(
            loan.holder == msg.sender &&
            loan.status == Status.ACTIVE
        );

        loansEth[id].status = Status.COMPLETED;
        token.transfer(loan.holder,loan.amount);
    }

    function returnEth(uint256 id) public payable {
        Loan memory loan = loansEth[id];
        uint256 needSend = loan.amount.add(loan.margin);

        require (
            loan.status == Status.USED &&
            msg.sender == loan.recipient &&
            msg.value >= needSend
        );

        loansEth[id].status = Status.COMPLETED;
        balance[loan.holder] = balance[loan.holder].add(needSend);
        token.transfer(msg.sender, loan.pledge);

        if (msg.value > needSend)
            msg.sender.transfer(msg.value - needSend);
    }

    function returnLibre(uint256 id) public {
        Loan memory loan = loansLibre[id];
        uint256 needBack = loan.amount.add(loan.margin);

        require (
            loan.status == Status.USED &&
            msg.sender == loan.recipient
        );

        loansLibre[id].status = Status.COMPLETED;
        token.transferFrom(msg.sender, this, needBack);
        token.transfer(loan.holder, needBack);
        balance[loan.recipient] = balance[loan.recipient].add(loan.pledge);
    }

    function claimEth(uint256 id) public {
        Loan memory loan = loansEth[id];

        require (
            msg.sender == loan.holder &&
            loan.status == Status.USED &&
            exchanger.getState() == ComplexExchanger.State.PROCESSING_ORDERS &&
            (now > (loan.timestamp + loan.period) || 
            calcPledgeEth(loan, marginCallPercent) > loan.pledge)
        );

        uint256 rate = exchanger.sellRate();
        uint256 needReturn = loan.amount.add(loan.margin);
        uint256 havePledge = loan.pledge.mul(RATE_MULTIPLIER) / rate;

        if (havePledge < needReturn)
          needReturn = havePledge;

        uint256 sellTokens = needReturn * rate / RATE_MULTIPLIER;

        loansEth[id].status = Status.COMPLETED;
        token.approve(Exchanger, sellTokens);
        exchanger.sellTokens(loan.holder, sellTokens);
    }
    

    function claimLibre(uint256 id) public {
        Loan memory loan = loansLibre[id];


        require (
            msg.sender == loan.holder &&
            loan.status == Status.USED &&
            exchanger.getState() == ComplexExchanger.State.PROCESSING_ORDERS &&
            (now > (loan.timestamp + loan.period) ||
            calcPledgeLibre(loan, marginCallPercent) > loan.pledge)
        );
        
        uint256 rate = exchanger.buyRate();
        uint256 needReturn = loan.amount.add(loan.margin);
        uint256 havePledge = loan.pledge * rate / RATE_MULTIPLIER;

        if (havePledge < needReturn)
          needReturn = havePledge;

        uint256 buyTokens = needReturn.mul(RATE_MULTIPLIER) / rate;

        loansLibre[id].status = Status.COMPLETED;
        exchanger.buyTokens.value(buyTokens)(loan.holder);
    }


    /**
     * @dev Returns loans count (Libre, Eth)
     */
    function loansCount() public view returns(uint256,uint256) {
        return (loansLibre.length,loansEth.length);
    }

    function tokenBalance() public view  returns(uint256) {
        return token.balanceOf(this);
    }

    /**
     * @dev Allows contract owner to set loans fee.
     * @param _feeLibre The fee percent in Libre
     * @param _feeEth The fee percent in Ether
     */
    function setFee(uint256 _feeLibre, uint256 _feeEth) public onlyOwner {
        feeLibre = _feeLibre;
        feeEth = _feeEth;
    }

    function setPercent(uint256 _percent) public onlyOwner {
        pledgePercent = _percent;
    }

    function setMarginCallPercent(uint256 _percent) public onlyOwner {
        marginCallPercent = _percent;
    }

    function refundAmount(Loan loan) internal view returns(uint256) {
        return loan.amount.add(loan.margin) * (100 * PERCENT_MULTIPLIER + loan.fee) / PERCENT_MULTIPLIER / 100;
    }

    function calcPledgeLibre(Loan loan, uint256 percent) internal view returns(uint256) {
        return refundAmount(loan).mul(RATE_MULTIPLIER) * percent / exchanger.buyRate() / PERCENT_MULTIPLIER / 100;
    }

    function calcPledgeEth(Loan loan, uint256 percent) internal view returns(uint256) {
        return refundAmount(loan).mul(exchanger.sellRate()) * percent / RATE_MULTIPLIER / PERCENT_MULTIPLIER / 100;
    }

    function takeLoanLibre(uint256 id) public payable {
        Loan memory loan = loansLibre[id];

        require(
            loan.status == Status.ACTIVE &&
            exchanger.getState() == ComplexExchanger.State.PROCESSING_ORDERS
        );

        uint256 pledge = calcPledgeLibre(loan, pledgePercent);
        uint256 refund = msg.value.sub(pledge); // throw ex if msg.value < pledge
        
        loan.recipient = msg.sender;
        loan.timestamp = now;
        loan.status = Status.USED;
        loan.pledge = pledge;
        loansLibre[id] = loan;

        token.transfer(msg.sender,loan.amount);

        if(refund > 0)
            msg.sender.transfer(refund);
        // LoanAccepted(id,msge.sender,pledge,loan.timestamp+loan.period);
    }

    function takeLoanEth(uint id) public {
        Loan memory loan = loansEth[id];

        require(
            loan.status == Status.ACTIVE &&
            exchanger.getState() == ComplexExchanger.State.PROCESSING_ORDERS
        );

        uint256 pledge = calcPledgeEth(loan, pledgePercent);

        loan.recipient = msg.sender;
        loan.timestamp = now;
        loan.status = Status.USED;
        loan.pledge = pledge;
        loansEth[id] = loan;

        token.transferFrom(msg.sender, this, pledge); // thow if user doesn't allow tokens
        msg.sender.transfer(loan.amount);
    }

    function withdraw() public onlyOwner {
        owner.transfer(address(this).balance);
    }

    function setExchanger(address _exchanger) public onlyOwner {
        Exchanger = _exchanger;
        exchanger = ComplexExchanger(Exchanger);
    }

    function setLibre(address _libre) public onlyOwner {
        Libre = _libre;
        token = LibreCash(Libre);
    }

    function claimBalance(uint256 _amount) public {
        require (balance[msg.sender] > 0);
        
        _amount = (_amount == 0) ? balance[msg.sender] : _amount;

        balance[msg.sender] = balance[msg.sender].sub(_amount);
        msg.sender.transfer(_amount);
    }
}