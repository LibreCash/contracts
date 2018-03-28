const
    reverter = new (require('./helpers/reverter'))(web3),
    timeMachine = new (require('./helpers/timemachine'))(web3),
    assertTx = new (require('./helpers/assertTx'))(),
    utils = new (require('./helpers/utils'))(),
    tokenMultiplier = Math.pow(10, 18),
    MORE_THAN_COSTS = web3.toWei(5,'ether'),
    ComplexExchanger = artifacts.require("ComplexExchanger"),
    LibreCash = artifacts.require("LibreCash"),
    Loans = artifacts.require("Loans");

function getLoanStruct(contractArray) {
    return {
        holder: contractArray[0],
        recipient: contractArray[1],
        timestamp: +contractArray[2][0],
        period: +contractArray[2][1],
        amount: +contractArray[2][2],
        margin: +contractArray[2][3],
        return: +contractArray[2][4],
        pledge: +contractArray[2][5],
        status: +contractArray[3]
    }
}


contract("Loans",function(accounts) {
    var owner = accounts[0],
        acc1  = accounts[1],
        exchanger,
        loans;

    before("init var", async function() {
        exchanger = await ComplexExchanger.deployed();
        token = await LibreCash.deployed();
        loans = await Loans.deployed();
    });

    context("loansEth",function() {
        before("init", reverter.snapshot);
        afterEach("revert", reverter.revert);

        it("create loan", async function() {
            let before = web3.eth.getBalance(owner);
            await loans.giveEth(1,web3.toWei(2,'ether'),web3.toWei(3,'ether'),{value: web3.toWei(4,'ether')});
            let after = web3.eth.getBalance(owner);
            let loan = getLoanStruct(await loans.getLoanEth(0));
            let takeEth = web3.fromWei(before - after - utils.gasCost());

            assert.isBelow(Math.abs(2 - takeEth),0.00001,"Take Eth not equal!");
            assert.equal(loan.holder, owner, "Holder not right!");
            assert.equal(loan.period, 1,"Period not right!");
            assert.equal(loan.amount, web3.toWei(2,'ether'),"Amount not right!");
            assert.equal(loan.margin, web3.toWei(3,'ether'),"Margin not right!");
            assert.equal(loan.status, 0, "Status not right!");
        });

        it("cancel loan", async function() {
            let before = web3.eth.getBalance(owner);
            await loans.giveEth(1,web3.toWei(2,'ether'),web3.toWei(3,'ether'),{value: web3.toWei(4,'ether')});
            let gasCost = utils.gasCost();
            await loans.cancelEth(0);
            gasCost += utils.gasCost();
            let after = web3.eth.getBalance(owner);
            let loan = getLoanStruct(await loans.getLoanEth(0));

            assert.equal(loan.status,2,"Don't right status!");
            assert.isBelow(before - after - gasCost, 10000, "Don't right balacne after cancel loan!");
        });

        it("take loan",async function() {
            await exchanger.requestRates({value: MORE_THAN_COSTS});
            await exchanger.calcRates();

            await token.mint(owner,10000);
            let before = + await token.balanceOf(owner);

            await token.approve(loans.address,10000);
            await loans.giveEth(1000,1,0,{value: 1});
            await loans.takeLoanEth(0);
            let after = +await token.balanceOf(owner);
            let loan = getLoanStruct(await loans.getLoanEth(0));

            assert.equal(before - after, loan.pledge, "token give and pledge not equal!");
            assert.equal(loan.recipient,owner,"Don't right recipient!");
        });
    });
});