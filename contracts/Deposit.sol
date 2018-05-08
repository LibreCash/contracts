pragma solidity ^0.4.18;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/ownership/Ownable.sol";

import "./token/LibreCash.sol";


contract Deposit is Ownable {
    using SafeMath for uint256;
    address public Libre;
    LibreCash libre;

    uint256 public needAmount = 20000 ether;
    uint256 constant REVERSE_PERCENT = 10000;
    uint256 constant YEAR_SECONDS = 365.25 * 24 * 60 * 60;
    uint256 public lockedTokens = 0;
    
    DepositPlan[] public plans;

    event NewDeposit(address beneficiar, uint256 timestamp, uint256 deadline, uint256 amount, uint256 margin);
    event ClaimDeposit(address beneficiar, uint256 amount, uint256 margin);

    struct OwnDeposit {
        uint256 timestamp;
        uint256 deadline;
        uint256 amount;
        uint256 margin;
        string plan;
    }

    struct DepositPlan {
        uint256 period;
        uint256 percent;
        uint256 minAmount;
        string description;
    }

    mapping (address => OwnDeposit[]) public deposits;
    mapping (address => uint256) public depositCount;

    /**
     * @dev Constructor
     */
    function Deposit() public {
        Libre = 0xdfddb278eee836636240eba0e47f4a86dcfd52de;
        libre = LibreCash(Libre);
    }

    /**
     * @dev Set amount the contract needs.
     * @param _amount New amount.
     */
    function setAmount(uint256 _amount) public onlyOwner {
        require(_amount > 0);
        needAmount = _amount;
    }

    /**
     * @dev Return length deposits array of sender.
     */
    function myDepositLength() public view returns(uint256) {
        return deposits[msg.sender].length;
    }

    /**
     * @dev Lets user to get back his deposit with margin after deadline.
     * @param _id Deposit ID.
     */
    function claimDeposit(uint256 _id) public {
        OwnDeposit storage dep = deposits[msg.sender][_id];
        require(dep.deadline <= now);
        uint256 refundAmount = dep.amount.add(dep.margin);
        lockedTokens = lockedTokens.sub(refundAmount);
        needAmount = needAmount.add(dep.amount);
        libre.transfer(msg.sender, refundAmount);
        emit ClaimDeposit(msg.sender, dep.amount, dep.margin);
        depositCount[msg.sender] = depositCount[msg.sender].sub(1);
        delete deposits[msg.sender][_id];
    }

    /**
     * @dev Creates deposit plan.
     * @param _period Deposit period (lifetime in seconds).
     * @param _percent Deposit percentage (annual).
     * @param _minAmount Minimum deposit amount.
     * @param _description Plan description.
     */
    function createPlan(uint256 _period, uint256 _percent, uint256 _minAmount, string _description) public onlyOwner {
        require(_period > 0 && _percent >= 0 && _minAmount >= 0);
        plans.push(DepositPlan(_period, _percent, _minAmount, _description));
    }

    /**
     * @dev Delete deposit plan.
     * @param _id Deposit plan ID.
     */
    function deletePlan(uint256 _id) public onlyOwner {
        delete plans[_id];
    }

    /**
     * @dev Change deposit plan.
     * @param _id Deposit plan ID.
     * @param _period Deposit period (lifetime in seconds).
     * @param _percent Deposit percentage (annual).
     * @param _minAmount Minimum deposit amount.
     * @param _description Plan description.
     */
    function changePlan(uint256 _id, uint256 _period, uint256 _percent, uint256 _minAmount, string _description) public onlyOwner {
        require(_period > 0 && _percent >= 0 && _minAmount >= 0);
        plans[_id] = DepositPlan(_period, _percent, _minAmount, _description);
    }

    /**
     * @dev Create deposit.
     * @param _amount Libre amount.
     * @param _planId Deposit plan ID.
     */
    function createDeposit(uint256 _amount, uint256 _planId) public {
        uint256 amount = (_amount <= needAmount) ? _amount : needAmount;
        DepositPlan memory plan = plans[_planId];
        uint256 margin = calcProfit(amount, _planId);
        
        //require(amount >= plan.minAmount && margin <= availableTokens());
        lockedTokens = lockedTokens.add(margin).add(amount);

        libre.transferFrom(msg.sender, this, amount);
        deposits[msg.sender].push(OwnDeposit(
            now,
            now.add(plan.period),
            amount,
            margin,
            plan.description
        ));

        needAmount = needAmount.sub(amount);
        depositCount[msg.sender] = depositCount[msg.sender].add(1);
        emit NewDeposit(msg.sender, now, now.add(plan.period), amount, margin);
    }

    /**
     * @dev Get available tokens on the deposit contract.
     */
    function availableTokens() public view returns(uint256) {
        return libre.balanceOf(this).sub(lockedTokens);
    }

    /**
     * @dev Calculate potential profit.
     * @param _amount Libre amount.
     * @param _planId Deposit plan ID.
     */
    function calcProfit(uint256 _amount, uint256 _planId) public view returns(uint256) {
        DepositPlan storage plan = plans[_planId];
        // yearlyProfitX100 = _amount * percent * 100
        uint256 yearlyProfitX100 = _amount.mul(plan.percent);
        // periodicProfit = yearlyProfitX100 * period / 365.25 days / 100
        uint256 periodicProfit = yearlyProfitX100.mul(plan.period).div(YEAR_SECONDS).div(REVERSE_PERCENT);
        return periodicProfit;
    }
    
    /**
     * @dev Gets deposit plans count.
     */
    function plansCount() public view returns(uint256) {
        return plans.length;
    }
}