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
    LOCKED: 0,
    PROCESSING_ORDERS: 1,
    WAIT_ORACLES: 2,
    CALC_RATES: 3,
    REQUEST_RATES: 4
}

const 
    minutes = 60,
    REVERSE_PERCENT = 100,
    RATE_MULTIPLIER = 1000,

    exConfig = {
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

        it("(2) check PROCESSING_ORDERS", async function() {
            let state = + await bank.getState.call(),
                calcTime = + await bank.calcTime.call();

            if (utils.now() - calcTime > exConfig.RATE_PERIOD) {
                assert.notEqual(state, StateENUM.PROCESSING_ORDERS, 
                    "Don't correct state when calcTime > RATE_PERIOD");
                await bank.requestRates({value: MORE_THAN_COSTS});
                await bank.calcRates();
                state = + await bank.getState.call();
            }

            assert.equal(state, StateENUM.PROCESSING_ORDERS,"Don't correct state when calcTime < RATE_PERIOD");
        });

        it("(3) check WAIT_ORACLES", async function() {
            await bank.requestRates({value: MORE_THAN_COSTS});
            let state = + await bank.getState.call(),
                waiting = + await bank.waitingOracles.call();

            if (waiting == 0) {
                assert.notEqual(state, StateENUM.WAIT_ORACLES, "Don't correct state when waitingOracles == 0");
                let oracle = await oracles[0].deployed();
                await oracle.setWaitQuery(true);

                state = + await bank.getState.call();
            }

            assert.equal(state, StateENUM.WAIT_ORACLES, "Don't correct state when waitingOracles != 0");
        });

        it("(4),(5) check CALC_RATES and REQUEST_RATES", async function() {
            await bank.requestRates({value: MORE_THAN_COSTS});

            let 
                state = + await bank.getState.call(),
                ready = + await bank.readyOracles.call();

            if (ready >= exConfig.MIN_READY_ORACLES) {
                assert.equal(state, StateENUM.CALC_RATES, 
                    "Don't correct state when readyOracles >= MIN_READY_ORACLES");
                for(let i=0; i < (oracles.length - exConfig.MIN_READY_ORACLES + 1); i++) {
                    let oracle = await oracles[i].deployed();
                    await oracle.setRate(0);
                }

                state = + await bank.getState.call();
            }

            assert.equal(state, StateENUM.REQUEST_RATES, 
                "Don't correct state when readyOracles < MIN_READY_ORACLES");
        });
    });

    context("waitingOracles", function() {

        before("init", reverter.snapshot);
        afterEach("revert", reverter.revert);

        it("(1),(3) time wait < ORACLE_TIMEOUT", async function() {
            await assertTx.success(bank.requestRates({value: MORE_THAN_COSTS}), 
                "requestRates failed");
            let waiting = + await bank.waitingOracles.call();
            assert.equal(waiting, 0, "WaitingOracles not 0 if 0 waiting!");
            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                assertTx.success(oracle.setWaitQuery(true));
                waiting = + await bank.waitingOracles.call();
                assert.equal(waiting, i + 1, `WaitingOracles not ${waiting} if ${i+1} waiting!`);
            }
        });

        it("(2) time wait > ORACLE_TIMEOUT", async function() {
            await assertTx.success(bank.requestRates({value: MORE_THAN_COSTS}), 
                "requestRates failed");
            for(let i=0; i< oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                await assertTx.success(oracle.setWaitQuery(true));
            }
            let waiting = + await bank.waitingOracles.call();
            assert.equal( waiting, oracles.length, "Don't equal waiting oracles!");
            await timeMachine.jump(exConfig.ORACLE_TIMEOUT + 1);

            waiting = + await bank.waitingOracles.call();
            assert.equal(waiting, 0, `${waiting} wait oracle when timeout!`);

            await timeMachine.jump(-exConfig.ORACLE_TIMEOUT - 1);
        });
    });

    context("readyOracles", function() {

        before("init", reverter.snapshot);
        afterEach("revert", reverter.revert);

        it("(1),(4) rate == 0 or wait == 0", async function() {
            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                await assertTx.success(oracle.setRate(0));
            }

            let ready = + await bank.readyOracles.call();
            assert.equal(ready, 0, "if rate == 0, ready oracles != 0");

            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                await assertTx.success(oracle.setRate(10));
                await assertTx.success(oracle.setWaitQuery(true));
            }

            ready = + await bank.readyOracles.call();
            assert.equal(ready, 0, "if wait oracle, ready oracle != 0");
        });

        it("(2) callbackTime < ORACLE_ACTUAL", async function() {
            await assertTx.success(bank.requestRates({value: MORE_THAN_COSTS}), 
                "requestRates failed");
            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                await assertTx.success(oracle.setWaitQuery(true));
                let ready = + await bank.readyOracles.call();
                assert.equal(ready, oracles.length - i -1, "");
            }
        });

        it("(3) callbackTime > ORACLE_ACTUAL", async function() {
            await assertTx.success(bank.requestRates({value: MORE_THAN_COSTS}), 
                "requestRates failed");
            let ready = + await bank.readyOracles.call();
            assert.equal(ready, oracles.length, "ready oracle don't equal count oracles");

            await timeMachine.jump(exConfig.ORACLE_ACTUAL +1);
            ready = + await bank.readyOracles.call();
            assert.equal(ready, 0, "ready oracles != 0, if ACTUAL timeout");

            await timeMachine.jump(-exConfig.ORACLE_ACTUAL - 1);
        });
    });

    context("buy tokens", function() {
        before("init", reverter.snapshot);
        beforeEach("calcRates",async function() {
            await bank.requestRates({value: MORE_THAN_COSTS});
            await bank.calcRates();
            let state = +await bank.getState.call();
            assert.equal(state,StateENUM.PROCESSING_ORDERS,"Wrong state!");
        });
        afterEach("revert", reverter.revert);

        it.only("buy value", async function() {
            await assertTx.fail(bank.buyTokens(owner, {value: 1}),
              "Tx need to fail if send 0 Tokens");
            await assertTx.success(bank.buyTokens(owner, {value: 1000}),
              "Tx need to success if send 1 ether");

            let buyRate = +await bank.buyRate.call(),
                balance = +await token.balanceOf(owner);

            assert.equal(buyRate, balance, "Buy and get tokens not equal!");
        });
    });

    context("requestRate", function() {
        var jump;

        before("init", async function() {
            await assertTx.success(bank.requestRates({from: acc1, value: MORE_THAN_COSTS}), 
                "requestRates tx falls");
            jump = Math.max(exConfig.ORACLE_ACTUAL, exConfig.ORACLE_TIMEOUT);
            await timeMachine.jump(jump + 1);
            
            let state = + await bank.getState.call();
            assert.equal(state, StateENUM.REQUEST_RATES,"Don't correct state!!");

            reverter.snapshot((e) => {
                if (e != undefined)
                    console.log(e);
            });
        });

        afterEach("revert", reverter.revert);

        after("time back", async function() {
            await timeMachine.jump(-jump -1);
        })

        it("(1) payAmount < oraclesCost", async function() {
            let oraclesCost = + await bank.requestPrice.call();

            await assertTx.fail(bank.requestRates(),"Don't throw if send == 0");
            await assertTx.fail(bank.requestRates({value: oraclesCost/2}),
                "Don't throw if send < oraclesCost");
        });

        it("(2) payAmount == oraclesCost", async function() {
            let oraclesCost = + await bank.requestPrice.call();

            await assertTx.success(bank.requestRates({value: oraclesCost}), 
                "requestRates failed");
        });

        it("(3) payAmount > oraclesCost", async function() {
            let oraclesCost = + await bank.requestPrice.call();
            let before = + web3.eth.getBalance(owner);

            await assertTx.success(bank.requestRates({value: oraclesCost + 10000000}), 
                "requestRates failed with value: oraclesCost + 10000000");

            let after = + web3.eth.getBalance(owner);
                weiUsed = utils.gasCost();

            assert.isBelow((before - after) - weiUsed - oraclesCost, 100000, "we didn't get back oversent ether");
        });
    });

    context("calcRate", function() {
        var oraclesDeployed = [];

        before("check state", async function() {
            let state = + await bank.getState.call();

            if (state != StateENUM.CALC_RATES) {
                await assertTx.success(bank.requestRates({value: MORE_THAN_COSTS}), 
                    "requestRates failed");
                state = + await bank.getState.call();
            }

            assert.equal(state, StateENUM.CALC_RATES,"Don't correct state!!");

            reverter.snapshot((e) => {
                if (e != undefined)
                    console.log(e);
            });
        });

        afterEach("revert", reverter.revert);

        it("(1) validOracles < MIN", async function() {
            for (let i = 0; i < (oracles.length - exConfig.MIN_READY_ORACLES +1); i++) {
                let oracle = await oracles[i].deployed();
                await assertTx.success(oracle.setRate(0), 
                    "oracle.setRate(0) failed");
            }

            await assertTx.fail(bank.calcRates(), 
                "calcRates shall fail when we have 0");
            
            for (let i = 0; i < exConfig.MIN_READY_ORACLES; i++) {
                let oracle = await oracles[i].deployed();
                await assertTx.success(oracle.setRate(1), 
                    "oracle.setRate(1) failed");
            }

            await assertTx.success(bank.calcRates(), 
                "calcRates shall success when we have > 0");
        });

        it("(2) validOracles > min", async function() {
            await assertTx.success(bank.calcRates(),"Error if calcRate with valid oracles");

            let max, min;
            for(let i = 0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                let rate = + await oracle.rate.call();

                max = (max === undefined) ? rate : Math.max(max,rate);
                min = (min === undefined) ? rate : Math.min(min,rate);
            }

            let 
                buyFee = + await bank.buyFee.call(),
                sellFee = + await bank.sellFee.call(),
                buyRate = + await bank.buyRate.call(),
                sellRate = + await bank.sellRate.call();

            calcBuyRate = min - min * buyFee/100/REVERSE_PERCENT;
            calcSellRate = max + max * sellFee/100/REVERSE_PERCENT;

            assert.equal(calcBuyRate, buyRate, "Don't equal calculate and return buyRate");
            assert.equal(calcSellRate, sellRate , "Don't equal calculate and return sellRate");
        });
    });
});