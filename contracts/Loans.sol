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

    uint256 public rateTime;
    uint256 public rate;
    uint256 public RATE_ACTUAL = 10 minutes;
    uint256 public requestTime;


    LibreCash token;
    ComplexExchanger exchanger;


    uint256 public fee = 200;
    uint256 public percent = 150;
    uint256 public constant REVERSE_PERCENT = 100;
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
        Loan memory curLoan = Loan(msg.sender,0x0,now,_period,_amount, _margin,Status.active);
        loansLibre.push(curLoan);

        NewLoan(Assets.eth, now, _period, _amount, _margin, Status.active);
    }

    function createLoanEth(uint256 _period, uint256 _amount, uint256 _margin) payable public {
        require(_amount <= msg.value &&_amount >= loanLimitEth.min && _amount <= loanLimitEth.max);
        
        uint256 refund = msg.value.sub(_amount);
        
        Loan memory curLoan = Loan(msg.sender, 0x0, now, _period, msg.value, _margin, Status.active);
        
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



    /**
     * @dev Returns loans count (Libre, Eth)
     */
    function loansCount() public view returns(uint256,uint256) {
        return (loansLibre.length,loansEth.length);
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