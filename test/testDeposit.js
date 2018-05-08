const
    reverter = new (require('./helpers/reverter'))(web3),
    timeMachine = new (require('./helpers/timemachine'))(web3),
    assertTx = new (require('./helpers/assertTx'))(),
    utils = new (require('./helpers/utils'))(),
    tokenMultiplier = Math.pow(10, 18),
    MORE_THAN_COSTS = web3.toWei(5, 'ether'),
    ComplexExchanger = artifacts.require('ComplexExchanger'),
    LibreCash = artifacts.require('LibreCash'),
    Deposit = artifacts.require('Deposit');

function getPlanStruct (contractArray) {
    return {
        period: +contractArray[0],
        percent: +contractArray[1],
        minAmount: +contractArray[2],
        description: contractArray[3],
    };
}

function getDepositStruct (contractArray) {
    return {
        timestamp: +contractArray[0],
        deadline: +contractArray[1],
        amount: +contractArray[2],
        margin: +contractArray[3],
        plan: contractArray[4],
    };
}

contract('Deposit', function (accounts) {
    var owner = accounts[0],
        acc1 = accounts[1],
        exchanger,
        token,
        deposit,
        plan;

    before('init var', async function () {
        exchanger = await ComplexExchanger.deployed();
        token = await LibreCash.deployed();
        deposit = await Deposit.deployed();
    });

    context('plan', function () {
        before('init', reverter.snapshot);
        afterEach('revert', reverter.revert);

        it('setAmount', async function () {
            await deposit.setAmount(123);
            let needAmount = await deposit.needAmount();

            assert.equal(needAmount, 123, 'Don\'t set needAmount!');
        });

        it('create', async function () {
            await assertTx.fail(deposit.createPlan(0, 1, 1, 'create'), 'Don\'t fail tx if period == 0!');
            
            let beforeCount = +await deposit.plansCount();
            await deposit.createPlan(1, 2, 3, 'create');
            let afterCount = +await deposit.plansCount();

            assert.equal(beforeCount + 1, afterCount, 'Count plans don\'t changed!');

            let plan = getPlanStruct(await deposit.plans(0));

            assert.equal(plan.period, 1, 'Period not equal!');
            assert.equal(plan.percent, 2, 'Percent not equal!');
            assert.equal(plan.minAmount, 3, 'MinAmount not equal!');
            assert.equal(plan.description, 'create', 'Description not equal!');
        });

        it('change', async function () {
            await deposit.createPlan(1, 2, 3, 'create');
            await deposit.changePlan(0, 4, 5, 6, 'change');

            let plan = getPlanStruct(await deposit.plans(0));

            assert.equal(plan.period, 4, 'Period not change!');
            assert.equal(plan.percent, 5, 'Percent not change!');
            assert.equal(plan.minAmount, 6, 'MinAmount not change!');
            assert.equal(plan.description, 'change', 'Description not change!');
        });

        it('delete', async function () {
            await deposit.createPlan(1, 2, 3, 'create');
            await deposit.deletePlan(0);

            let plan = getPlanStruct(await deposit.plans(0));

            assert.equal(plan.period, 0, 'Period not deleted!');
            assert.equal(plan.percent, 0, 'Percent not deleted!');
            assert.equal(plan.minAmount, 0, 'MinAmount not deleted!');
            assert.equal(plan.description, '', 'Description not deleted!');
        });

        it('calcProfit', async function () {
            await deposit.createPlan(60 * 60 * 24 * 365.25, 100 * 100, 3, 'calc');

            let profit = +await deposit.calcProfit(1000, 0);

            assert.equal(profit, 1000, 'Don\'t right profit!');
        });
    });

    context('deposit', function () {
        before('init', async function () {
            await deposit.createPlan(10, 2000, 3000, 'one');
            plan = getPlanStruct(await deposit.plans(0));

            reverter.snapshot(err => {
                if (err) console.log(err);
            });
        });

        afterEach('revert', reverter.revert);

        it('create', async function () {
            await token.approve(deposit.address, 0);
            await assertTx.fail(deposit.createDeposit(plan.minAmount, 0),
                'Tx not fail, but not available tokens!');

            await token.mint(owner, plan.minAmount);
            await token.approve(deposit.address, plan.minAmount);

            await assertTx.fail(deposit.createDeposit(plan.minAmount - 1, 0),
                'Tx not fail, but amount less then need!');
            
            let beforeCount = +await deposit.myDepositLength();
            let beforeTokens = await token.balanceOf(owner);
            await deposit.createDeposit(plan.minAmount, 0);
            let afterCount = +await deposit.myDepositLength();
            let afterTokens = await token.balanceOf(owner);

            assert.equal(beforeCount + 1, afterCount, 'Count deposits not changed!');
            assert.equal(beforeTokens.minus(afterTokens).minus(plan.minAmount), 0,
                'Don\'t equal amount tokens!');

            let myDeposit = getDepositStruct(await deposit.deposits(owner, 0));

            assert.equal(myDeposit.amount, plan.minAmount, 'Don\'t equal amount deposit!');
            assert.equal(myDeposit.deadline - myDeposit.timestamp, plan.period,
                'Don\'t equal period deposit!');
            assert.equal(myDeposit.plan, plan.description, 'Don\'t correct plan name!');
        });

        it('claim', async function () {
            await deposit.createDeposit(plan.minAmount, 0);
            let myDeposit = getDepositStruct(await deposit.deposits(owner, 0));

            await assertTx.fail(deposit.claimDeposit(0),
                'Don\'t fail claim, if deadline did not come!');

            await timeMachine.jump(plan.period + 1);

            let before = await token.balanceOf(owner);
            await deposit.claimDeposit(0);
            let after = await token.balanceOf(owner);

            assert.equal(+after.minus(before), myDeposit.amount + myDeposit.margin,
                'Don\'t right amount tokens return!');
        });
    });
});
