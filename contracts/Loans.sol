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

    uint256 public constant percent = 200;
    uint256 public constant REVERSE_PERCENT = 100;

    struct Limit {
        uint256 min;
        uint256 max;
    }

    Limit public loanLimitEth = Limit(1000 wei, 1 ether);
    Limit public loanLimitLibre = Limit(100 wei, 100 ether);

    event NewLoan(Assets asset, uint256 timestamp, uint256 deadline, uint256 amount, uint256 margin, Status status);

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
        uint256 timestamp;
        uint256 deadline;
        uint256 amount;
        uint256 margin;
        Status status;
    }

    function Loans(address _libre, address _exchanger) public {
        require(_libre != 0x0 && _exchanger != 0x0);
        Libre = _libre;
        Exchanger = _exchanger;
        token = LibreCash(Libre);
        exchanger = ComplexExchanger(Exchanger);
    }


    function getLoanLibre(uint256 id) public view returns(uint256,uint256,uint256,uint256,Status) {
        Loan memory loan = loansLibre[id];
        return (loan.timestamp,loan.deadline,loan.amount,loan.margin,loan.status);
    }

    function getLoanEth(uint256 id) public view returns(uint256,uint256,uint256,uint256,Status) {
        Loan memory loan = loansEth[id];
        return (loan.timestamp,loan.deadline,loan.amount,loan.margin,loan.status);
    }

    function createLoanLibre(uint256 _deadline, uint256 _amount, uint256 _margin) public {
        require(_deadline > now  && _amount >= loanLimitLibre.min && _amount <= loanLimitLibre.max);
        
        token.transferFrom(msg.sender,this,_amount);
        Loan memory curLoan = Loan(now,_deadline,_amount, _margin,Status.active);
        loansLibre.push(curLoan);

        NewLoan(Assets.eth, now, _deadline, _amount, _margin, Status.active);
    }

    function createLoanEth(uint256 _deadline, uint256 _amount, uint256 _margin) payable public {
        require(_deadline > now && _amount >= msg.value);
        require(_amount >= loanLimitEth.min && _amount <= loanLimitEth.max);
        
        uint256 refund = msg.value.sub(_amount);
        
        Loan memory curLoan = Loan(now,_deadline,msg.value,_margin,Status.active);
        
        loansEth.push(curLoan);
        
        NewLoan(Assets.libre, now, _deadline, _amount, _margin, Status.active);

        if(refund > 0)
            msg.sender.transfer(refund);

    }

    function loansCount() public view returns(uint256,uint256) {
        return (loansLibre.length,loansEth.length);
    }

    function tokenBalance() public view  returns(uint256) {
        return token.balanceOf(this);
    }

    function isRateActual() public view returns(bool) {
        return exchanger.getState() == ComplexExchanger.State.PROCESSING_ORDERS;
    }

    function LibreRates() public view returns(uint256,uint256) {
        return (exchanger.buyRate(),exchanger.sellRate());
    }
}