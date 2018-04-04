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

    mapping(address=>OwnDeposit[]) public deposits;

    function Deposit(address _libre) public {
        Libre = _libre;
        libre = LibreCash(Libre);
    }

    function setAmount(uint256 _amount) public onlyOwner {
        needAmount = _amount;
    }

    function myDeposit(uint256 id) public view returns(uint256, uint256, uint256, uint256) {
        OwnDeposit memory dep = deposits[msg.sender][id];
        return (
            dep.timestamp,
            dep.deadline,
            dep.amount,
            dep.margin   
        );
    }

    function claimDeposit(uint256 id) public {
        OwnDeposit dep = deposits[msg.sender][id];
        require(dep.deadline >= now);
        uint256 refundAmount = dep.amount.add(dep.margin);
        libre.transfer(msg.sender, refundAmount);
        delete deposits[msg.sender][id];
        ClaimDeposit(msg.sender, dep.amount, dep.margin);
    }

    function createPlan(uint256 period, uint256 percent, uint256 minAmount) public onlyOwner {
        require(period > 0);
        plans.push(DepositPlan(period, percent, minAmount));
    }

    function deletePlan(uint256 planId) public onlyOwner {
        delete plans[planId];
    }

    function changePlan(uint256 planId, uint256 period, uint256 percent, uint256 minAmount) public onlyOwner {
        require(period > 0);
        plans[planId] = DepositPlan(period, percent, minAmount);
    }

    function getPlan(uint256 planId) public view returns(uint256 period, uint256 percent, uint256 minAmount) {
      period = plans[planId];
      percent = plans[planId];
      minAmount = plans[planId]
    }

    function createDeposit(uint256 _amount, uint256 planId) public {
        _amount = (_amount <= needAmount) ? _amount : needAmount;
        DepositPlan memory plan = plans[planId];
        uint256 margin = _amount.add(calcProfit(_amount, planId));
        
        lockedTokens.add(margin);
        require(_amount >= plan.minAmount && margin <= availableTokens());
        lockedTokens.add(_amount);


        libre.transferFrom(msg.sender, this, _amount);
        deposits[msg.sender].push(OwnDeposit(
            now,
            now.add(plan.period),
            _amount,
            margin
        ));

        needAmount.sub(_amount);
        NewDeposit(msg.sender, now, now.add(plan.period), _amount, margin);
    }

    function availableTokens() public view returns(uint256) {
        return libre.balanceOf(this).sub(lockedTokens);   
    }

    function calcProfit(uint256 _amount, uint256 _planId) public view returns(uint256) {
        DepositPlan storage plan = plans[_planId];
        // yearlyProfitX100 = _amount * percent * 100
        uint256 yearlyProfitX100 = _amount.mul(plan.percent);
        // periodicProfit = yearlyProfitX100 * period / 365.25 days / 100
        uint256 periodicProfit = yearlyProfitX100.mul(plan.period).div(YEAR_SECONDS).div(REVERSE_PERCENT);
        return periodicProfit;
    }
}