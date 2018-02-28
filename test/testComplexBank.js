const
    reverter = new (require('./helpers/reverter'))(web3),
    timeMachine = new (require('./helpers/timemachine'))(web3),
    assertTx = new (require('./helpers/assertTx'))(),
    utils = new (require('./helpers/utils'))(),
    tokenMultiplier = Math.pow(10, 18),
    MORE_THAN_COSTS = web3.toWei(5,'ether');

var ComplexBank = artifacts.require("ComplexBank");
var LibreCash = artifacts.require("LibreCash");

var oracles = [];
[
    "OracleMockLiza",
    "OracleMockSasha",
    "OracleMockKlara",
    "OracleMockTest",
    //"OracleMockRandom"
].forEach( (filename) => {
    oracles.push(artifacts.require(filename));
});

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

 const OracleENUM = {
     name:0,
     oracleType:1,
     updateTime:2,
     enabled:3,
     waitQuery:4,
     rate:5,
     next:6
};

const StateENUM = {
    REQUEST_RATES: 0,
    WAIT_ORACLES: 1,
    CALC_RATES: 2,
    PROCESS_ORDERS: 3,
    ORDER_CREATION: 4
}

const 
    minutes = 60,
    REVERSE_PERCENT = 100,
    RATE_MULTIPLIER = 1000,

    bankConfig = {
        buyFee:250,
        sellFee:250,
        MIN_RATE:100 * RATE_MULTIPLIER,
        MAX_RATE:5000 * RATE_MULTIPLIER,
        MIN_READY_ORACLES:2,
        ORACLE_ACTUAL:10 * minutes,
        ORACLE_TIMEOUT:10 * minutes,
        RATE_PERIOD:10 * minutes
    };
    

contract('ComplexBank', function(accounts) {
    var owner = accounts[0],
        acc1  = accounts[1],
        bank,
        token;

    before("init var", async function() {
        bank = await ComplexBank.deployed();
        token = await LibreCash.deployed();
    });

    context("getState", async function() {
        var jump;

        before("init", reverter.snapshot);
        afterEach("revert", reverter.revert);

        it('REQUEST_RATES',async function() {
            let state = +await bank.getState.call();
            assert.equal(state, StateENUM.REQUEST_RATES, "Don't right state after deploy!");

            await bank.requestRates({value: MORE_THAN_COSTS});
            state = +await bank.getState.call();
            assert.notEqual(state, StateENUM.REQUEST_RATES, "Don't right state after requestRates!");

            for (let i=0; i < (oracles.length - bankConfig.MIN_READY_ORACLES + 1); i++) {
                let oracle = await oracles[i].deployed();
                await oracle.setRate(0);
            }
            state = +await bank.getState.call();
            assert.equal(state, StateENUM.REQUEST_RATES, 
                "Don't right state if not enough ready oracles!");
        });

        it('ORDER_CREATION', async function() {
            await bank.requestRates({value: MORE_THAN_COSTS});
            let state = +await bank.getState.call();
            assert.notEqual(state, StateENUM.ORDER_CREATION, "Don't right state after deploy!");

            let queuePeriod = +await bank.queuePeriod.call();
            timeMachine.jump(1 + queuePeriod);
            state = +await bank.getState.call();
            assert.equal(state, StateENUM.ORDER_CREATION, "Don't right state after queue period!");
            
            let relevancePeriod = +await bank.relevancePeriod.call();
            timeMachine.jump(relevancePeriod - queuePeriod);
            await bank.requestRates({value: MORE_THAN_COSTS});
            await bank.calcRates();
            state = +await bank.getState.call();
            assert.equal(state, StateENUM.ORDER_CREATION, "Don't right state if not orders!");
        });

        it('WAIT_ORACLES',async function() {
            await bank.requestRates({value: MORE_THAN_COSTS});
            let state = +await bank.getState.call();
            assert.notEqual(state, StateENUM.WAIT_ORACLES, "Don't right state! Oracles not wait!");
            
            let oracle = await oracles[0].deployed();
            oracle.setWaitQuery(true);
            state = +await bank.getState.call();
            assert.equal(state, StateENUM.WAIT_ORACLES, "Don't right state! One oracle wait!");
        });

        it('CALC_RATES',async function() {
            await bank.requestRates({value: MORE_THAN_COSTS});
            let state = +await bank.getState.call();
            assert.equal(state, StateENUM.CALC_RATES, "Don't right state! All oracles ready!");

            for (let i=0; i < (oracles.length - bankConfig.MIN_READY_ORACLES + 1); i++) {
                let oracle = await oracles[i].deployed();
                await oracle.setRate(0);
            }
            state = +await bank.getState.call();
            assert.notEqual(state, StateENUM.CALC_RATES, 
                "Don't right state! Ready oracle < MIN_READY_ORACLES");
        });

        it('PROCESS_ORDERS',async function() {
            await bank.requestRates({value: MORE_THAN_COSTS});
            await bank.calcRates();
            let state = +await bank.getState.call();
            assert.notEqual(state, StateENUM.PROCESS_ORDERS,
                "Don't have orders! But state PROCESS_ORDERS");

            await bank.sendTransaction({value: 10000});
            let relevancePeriod = +await bank.relevancePeriod.call();
            timeMachine.jump(1 + relevancePeriod);

            await bank.requestRates({value: MORE_THAN_COSTS});
            await bank.calcRates();
            state = +await bank.getState.call();
            assert.equal(state, StateENUM.PROCESS_ORDERS, "Don't right state if have orders!");
        });
    });
});