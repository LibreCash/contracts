const
    reverter = new (require('./helpers/reverter'))(web3),
    timeMachine = new (require('./helpers/timemachine'))(web3),
    assertTx = new (require('./helpers/assertTx'))(),
    utils = new (require('./helpers/utils'))(),
    tokenMultiplier = Math.pow(10, 18),
    MORE_THAN_COSTS = web3.toWei(5,'ether'),
    ComplexExchanger = artifacts.require("ComplexExchanger"),
    LibreCash = artifacts.require("LibreCash"),
    Deposit = artifacts.require("Deposit");


contract("Deposit",function(accounts) {
    var owner = accounts[0],
        acc1  = accounts[1],
        exchanger,
        token,
        deposit;

    before("init var", async function() {
        exchanger = await ComplexExchanger.deployed();
        token = await LibreCash.deployed();
        Deposit = await Deposit.deployed();
    });
});