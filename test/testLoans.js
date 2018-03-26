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

        it("accept loan",async function() {
            await exchanger.requestRates({value: MORE_THAN_COSTS});
            await exchanger.calcRates();
            console.log("rate",+await exchanger.buyRate.call());
            await token.mint(owner,10000);
            console.log("tokens",+await token.balanceOf(owner));
            await token.approve(loans.address,10000);
            await loans.createLoanEth(1000,1,0,{value: 1});
            console.log("state", +await exchanger.getState());
            console.log("loan", await loans.getLoanEth(0));
            console.log("calcPledge",+await loans.calcPledgeEth(1,0));
            await loans.acceptLoanEth(0);
            console.log("tokens", +await token.balanceOf(owner));
        });
    });
});