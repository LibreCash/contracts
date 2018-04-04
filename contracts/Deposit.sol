
pragma solidity ^0.4.18;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/lifecycle/Pausable.sol";
import "./zeppelin/ownership/Ownable.sol";
import "./interfaces/I_Bank.sol";
import "./token/LibreCash.sol";
import "./ComplexExchanger.sol";


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
    }

    struct DepositPlan {
        uint256 period;
        uint256 percent;
        uint256 minAmount;
    }

    mapping (address => OwnDeposit[]) public deposits;

    /**
     * @dev Constructor.
     * @param _libre Address of LibreCash contract.
     */
    function Deposit(address _libre) public {
        Libre = _libre;
        libre = LibreCash(Libre);
    }

    /**
     * @dev Set amout the contract needs.
     * @param _amount New amount.
     */
    function setAmount(uint256 _amount) public onlyOwner {
        needAmount = _amount;
    }

    /**
     * @dev View method with deposit information.
     * @param _id Deposit ID.
     */
    function myDeposit(uint256 _id) public view returns(uint256, uint256, uint256, uint256) {
        OwnDeposit memory dep = deposits[msg.sender][_id];
        return (
            dep.timestamp,
            dep.deadline,
            dep.amount,
            dep.margin   
        );
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
        delete deposits[msg.sender][_id];
        ClaimDeposit(msg.sender, dep.amount, dep.margin);
    }

    /**
     * @dev Creates deposit plan.
     * @param _period Deposit period (lifetime in seconds).
     * @param _percent Deposit percentage (annual).
     * @param _minAmount Minimum deposit amount.
     */
    function createPlan(uint256 _period, uint256 _percent, uint256 _minAmount) public onlyOwner {
        require(_period > 0);
        plans.push(DepositPlan(_period, _percent, _minAmount));
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
     */
    function changePlan(uint256 _id, uint256 _period, uint256 _percent, uint256 _minAmount) public onlyOwner {
        require(_period > 0);
        plans[_id] = DepositPlan(_period, _percent, _minAmount);
    }

    /**
     * @dev Create deposit.
     * @param _amount Libre amount.
     * @param _planId Deposit plan ID.
     */
    function createDeposit(uint256 _amount, uint256 _planId) public {
        _amount = (_amount <= needAmount) ? _amount : needAmount;
        DepositPlan memory plan = plans[_planId];
        uint256 margin = calcProfit(_amount, _planId);
        
        lockedTokens = lockedTokens.add(margin);
        lockedTokens = lockedTokens.add(_amount);
        require(_amount >= plan.minAmount && _amount.add(margin) <= availableTokens());

        libre.transferFrom(msg.sender, this, _amount);
        deposits[msg.sender].push(OwnDeposit(
            now,
            now.add(plan.period),
            _amount,
            margin
        ));

        needAmount = needAmount.sub(_amount);
        NewDeposit(msg.sender, now, now.add(plan.period), _amount, margin);
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
}