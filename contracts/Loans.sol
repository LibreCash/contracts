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

    uint256 constant MAX_UINT256 = 2**256 - 1;

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

    /**
     * @dev Constructor
     * @param _libre address libre contract
     * @param _exchanger address exchanger contract
     */
    function Loans(address _libre, address _exchanger) public {
        require(_libre != 0x0 && _exchanger != 0x0);
        Libre = _libre; 
        Exchanger = _exchanger;
        token = LibreCash(Libre);
        exchanger = ComplexExchanger(Exchanger);
    }

    /**
     * @dev Returns loan in loansLibre
     * @param id index in loansLibre
     */
    function getLoanLibre(uint256 id) public view returns(address,address,uint256[6],Status) {
        return getLoan(Assets.LIBRE, loansLibre[id]);
    }

    /**
     * @dev Returns loans in loansEth
     * @param id index in loansEth
     */
    function getLoanEth(uint256 id) public view returns(address,address,uint256[6],Status) {
        return getLoan(Assets.ETH, loansEth[id]);
    }

    /**
     * @dev Returns array with loan fields
     * @param asset select type array
     * @param loan Loan struct element
     */
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

    /**
     * @dev Returns need pledge for loan
     * @param asset select type array
     * @param loan Loan struct element
     */
    function calcPledge(Assets asset,Loan loan) internal returns(uint256) {
        return asset == Assets.LIBRE ? calcPledgeLibre(loan, pledgePercent) :
                            calcPledgeEth(loan, pledgePercent);
    }

    /**
     * @dev create new loan Libre
     * @param _period period for loan
     * @param _amount amount Libre
     * @param _margin add Libre after period
     */
    function giveLibre(uint256 _period, uint256 _amount, uint256 _margin) public {
        require(_amount >= loanLimitLibre.min && _amount <= loanLimitLibre.max);
        
        token.transferFrom(msg.sender,this,_amount);
        Loan memory curLoan = Loan(msg.sender, 0x0, now, _period, _amount, _margin, feeLibre, 0, Status.ACTIVE);
        loansLibre.push(curLoan);

        NewLoan(Assets.ETH, now, _period, _amount, _margin, Status.ACTIVE);
    }

    /**
     * @dev create new loan Eth
     * @param _period period for loan
     * @param _amount amount Eth
     * @param _margin add Eth after period
     */
    function giveEth(uint256 _period, uint256 _amount, uint256 _margin) payable public {
        require(_amount <= msg.value &&_amount >= loanLimitEth.min && _amount <= loanLimitEth.max);
        
        uint256 refund = msg.value.sub(_amount);
        
        Loan memory curLoan = Loan(msg.sender, 0x0, now, _period, _amount, _margin, feeEth, 0, Status.ACTIVE);
        
        loansEth.push(curLoan);
        
        NewLoan(Assets.LIBRE,now, _period, _amount, _margin, Status.ACTIVE);

        if(refund > 0)
            msg.sender.transfer(refund);

    }

    /**
     * @dev cancel loan Eth
     * @param id index in loanEth
     */
    function cancelEth(uint256 id) public {
        Loan memory loan = loansEth[id];
        require(
            loan.holder == msg.sender &&
            loan.status == Status.ACTIVE
        );

        loansEth[id].status = Status.COMPLETED;
        loansEth[id].holder.transfer(loan.amount);
    }

    /**
     * @dev cancel loan Libre
     * @param id index in loanLibre
     */
    function cancelLibre(uint256 id) public {
        Loan memory loan = loansLibre[id];
        require(
            loan.holder == msg.sender &&
            loan.status == Status.ACTIVE
        );

        loansEth[id].status = Status.COMPLETED;
        token.transfer(loan.holder,loan.amount);
    }

    /**
     * @dev Return debt
     * @param id index in loanEth
     */
    function returnEth(uint256 id) public payable {
        Loan memory loan = loansEth[id];
        uint256 needSend = loan.amount.add(loan.margin);
        uint256 needReturn = refundAmount(loan);

        require (
            loan.status == Status.USED &&
            msg.sender == loan.recipient &&
            msg.value >= needReturn
        );

        loansEth[id].status = Status.COMPLETED;
        balance[loan.holder] = balance[loan.holder].add(needSend);
        balance[owner] = balance[owner].add(needReturn - needSend);
        token.transfer(msg.sender, loan.pledge);

        if (msg.value > needSend)
            msg.sender.transfer(msg.value - needSend);
    }

    /**
     * @dev Return debt
     * @param id index in loanLibre
     */
    function returnLibre(uint256 id) public {
        Loan memory loan = loansLibre[id];
        uint256 needSend = loan.amount.add(loan.margin);
        uint256 needReturn = refundAmount(loan);

        require (
            loan.status == Status.USED &&
            msg.sender == loan.recipient
        );

        loansLibre[id].status = Status.COMPLETED;
        token.transferFrom(msg.sender, this, needReturn);
        token.transfer(loan.holder, needSend);
        token.transfer(owner, needReturn - needSend);
        balance[loan.recipient] = balance[loan.recipient].add(loan.pledge);
    }

    /**
     * @dev Claim return debt
     * @param id index in loanEth
     */
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
        uint256 needSend = loan.amount.add(loan.margin);
        uint256 havePledge = loan.pledge.mul(RATE_MULTIPLIER) / rate;

        if (havePledge < needSend)
            needSend = havePledge;

        require(Exchanger.balance >= needSend);
        uint256 sellTokens = needSend * rate / RATE_MULTIPLIER;

        loansEth[id].status = Status.COMPLETED;
        token.approve(Exchanger,sellTokens);
        exchanger.sellTokens(loan.holder,sellTokens);
        if (loan.pledge > sellTokens)
            token.transfer(owner, loan.pledge - sellTokens);
    }

    /**
     * @dev Claim return debt
     * @param id index in loanLibre
     */
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
        uint256 needSend = loan.amount.add(loan.margin);
        uint256 havePledge = loan.pledge * rate / RATE_MULTIPLIER;

        if (havePledge < needSend)
          needSend = havePledge;

        require(token.balanceOf(Exchanger) >= needSend);
        uint256 buyTokens = needSend.mul(RATE_MULTIPLIER) / rate;

        loansLibre[id].status = Status.COMPLETED;
        exchanger.buyTokens.value(buyTokens)(loan.holder);
        if (loan.pledge > buyTokens)
          balance[owner] = balance[owner].add(loan.pledge - buyTokens);
    }


    /**
     * @dev Returns loans count (Libre, Eth)
     */
    function loansCount() public view returns(uint256,uint256) {
        return (loansLibre.length,loansEth.length);
    }

    function getLoans(uint256[2] _pagination, uint8 _type, uint8 _statuses) public view returns (uint256[], uint256) {
        // _pagination [_page, _pageCount]
        uint256 firstOrder = _pagination[0] * _pagination[1];
        // 1 - eth, 0 - libre (check?)
        Loan[] memory loans = (_type == 1) ? loansEth : loansLibre;
        // statuses:
        // 000 - 0 - none
        // 001 - 1 - active
        // 010 - 2 - used
        // 011 - 3 - active & used
        // 100 - 4 - completed
        // 101 - 5 - completed & active
        // 110 - 6 - completed & used
        // 111 - 7 - all
        // 1xxx - own
        // isActive * 1 + isUsed * 2 + isCompleted * 4 + isOwn * 8
        bool isActive = (_statuses % 2) != 0;
        bool isUsed = (_statuses / 2 % 2) != 0;
        bool isCompleted = (_statuses / 4 % 4) != 0;
        bool isOwn = (_statuses / 8 % 8) != 0;

        uint256[] memory orders = new uint256[](_pagination[1]);
        for (uint256 i = 0; i < _pagination[1]; i++) {
            orders[i] = MAX_UINT256;
        }
        uint256 counter = 0;
        for (i = 0; i < loans.length; i++) {
            bool _active = ((isActive && (loans[i].status == Status.ACTIVE)) ||
                            (isUsed && (loans[i].status == Status.USED)) ||
                            (isCompleted && (loans[i].status == Status.COMPLETED)));
            _active = isOwn ? loans[i].holder == msg.sender && _active : _active;
            if (_active) {
                counter++;
            }
            if (counter - 1 < firstOrder || counter - 1 > firstOrder + _pagination[1] - 1) continue;
            if (_active) {
                orders[counter - firstOrder - 1] = i;
            }
        }
        return (orders, counter);
    }

    // method only for tests
    function fillTestLoans() public {
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 100, 1000, 200, 0, Status.ACTIVE));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 200, 1100, 200, 0, Status.ACTIVE));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 300, 1200, 200, 0, Status.USED));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 400, 1300, 200, 0, Status.ACTIVE));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 500, 1400, 200, 0, Status.COMPLETED));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 600, 1500, 200, 0, Status.ACTIVE));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 700, 1600, 200, 0, Status.ACTIVE));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 800, 1700, 200, 0, Status.ACTIVE));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 900, 1800, 200, 0, Status.USED));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 1000, 1900, 200, 0, Status.ACTIVE));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 1100, 2000, 200, 0, Status.ACTIVE));   
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 1200, 2100, 200, 0, Status.COMPLETED));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 1300, 2200, 200, 0, Status.ACTIVE));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 1400, 2300, 200, 0, Status.ACTIVE));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 1500, 2400, 200, 0, Status.ACTIVE));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 1600, 2500, 200, 0, Status.USED));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 1700, 2600, 200, 0, Status.ACTIVE));        
        loansEth.push(Loan(msg.sender, 0x0, now, 300, 1800, 2700, 200, 0, Status.ACTIVE));   

        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 111, 11, 200, 0, Status.USED));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 222, 22, 200, 0, Status.USED));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 333, 33, 200, 0, Status.ACTIVE));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 444, 44, 200, 0, Status.COMPLETED));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 555, 55, 200, 0, Status.USED));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 666, 66, 200, 0, Status.USED));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 777, 77, 200, 0, Status.ACTIVE));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 888, 88, 200, 0, Status.ACTIVE));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 999, 99, 200, 0, Status.ACTIVE));        
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 1111, 111, 200, 0, Status.USED));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 2222, 222, 200, 0, Status.ACTIVE));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 3333, 333, 200, 0, Status.ACTIVE));
        loansLibre.push(Loan(msg.sender, 0x0, now, 222, 4444, 444, 200, 0, Status.ACTIVE));        
    }

    /**
     * @dev Return token balance
     */
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

    /**
     * @dev Set percent to pledge
     * @param _percent pledge percent
     */
    function setPercent(uint256 _percent) public onlyOwner {
        pledgePercent = _percent;
    }

    /**
     * @dev Set percent to MarginCall
     * @param _percent MarginCall percent
     */
    function setMarginCallPercent(uint256 _percent) public onlyOwner {
        marginCallPercent = _percent;
    }

    /**
     * @dev calc need to retrun for loan with fee
     * @param loan loan for calc
     */
    function refundAmount(Loan loan) internal view returns(uint256) {
        return loan.amount.add(loan.margin) * (100 * PERCENT_MULTIPLIER + loan.fee) / PERCENT_MULTIPLIER / 100;
    }

    /**
     * @dev calc pledge for loan in Libre
     * @param loan loan for calc
     * @param percent for calc
     */
    function calcPledgeLibre(Loan loan, uint256 percent) internal view returns(uint256) {
        return refundAmount(loan).mul(RATE_MULTIPLIER) * percent / exchanger.buyRate() / PERCENT_MULTIPLIER / 100;
    }

    /**
     * @dev calc pledge for loan in Eth
     * @param loan loan for calc
     * @param percent for calc
     */
    function calcPledgeEth(Loan loan, uint256 percent) internal view returns(uint256) {
        return refundAmount(loan).mul(exchanger.sellRate()) * percent / RATE_MULTIPLIER / PERCENT_MULTIPLIER / 100;
    }

    /**
     * @dev Take loan in Libre
     * @param id select loan in loansLibre
     */
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

    /**
     * @dev Take loan in Eth
     * @param id select loan in loansEth
     */
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

    /**
     * @dev withdraw all balance
     */
    function withdraw() public onlyOwner {
        owner.transfer(address(this).balance);
    }

    /**
     * @dev set exchanger address
     * @param _exchanger contract address
     */
    function setExchanger(address _exchanger) public onlyOwner {
        Exchanger = _exchanger;
        exchanger = ComplexExchanger(Exchanger);
    }

    /**
     * @dev set libre address
     * @param _libre contract address
     */
    function setLibre(address _libre) public onlyOwner {
        Libre = _libre;
        token = LibreCash(Libre);
    }

    /**
     * @dev claim balance
     * @param _amount amount to send
     */
    function claimBalance(uint256 _amount) public {
        require (balance[msg.sender] > 0);
        
        _amount = (_amount == 0) ? balance[msg.sender] : _amount;

        balance[msg.sender] = balance[msg.sender].sub(_amount);
        msg.sender.transfer(_amount);
    }
}