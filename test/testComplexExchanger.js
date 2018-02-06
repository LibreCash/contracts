var ComplexExchanger = artifacts.require("ComplexExchanger");

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

function sleep(miliseconds) {
    var currentTime = new Date().getTime();
 
    while (currentTime + miliseconds >= new Date().getTime()) {
    }
 }
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

contract('ComplexExchanger', function(accounts) {
    var owner = accounts[0];
    var acc1  = accounts[1];
    var acc2  = accounts[2];
    var oracle1 = oracles[3];

    context("getState", async function() {

        before("init", async function() {
            let exchanger = await ComplexExchanger.deployed();

            var oraclePromises = [];
            //oracles.forEach(oracle => oraclePromises.push(oracle.deployed()));
            //await Promise.all(oraclePromises);
        });
        
        it.only("get initial states", async function() {
            var exchanger = await ComplexExchanger.deployed();
            var state = await exchanger.getState.call();
            var buyFee = await exchanger.buyFee.call();
            var sellFee = await exchanger.sellFee.call();
            var deadline = await exchanger.deadline.call();
            var calcTime = await exchanger.calcTime.call();
            var requestTime = await exchanger.requestTime.call();
            //var _oracles = await exchanger.oracles.call();
            //console.log(_oracles);
            var tokenAddress = await exchanger.tokenAddress.call();
            var withdrawWallet = await exchanger.withdrawWallet.call();
            assert.equal(state.toNumber(), 4, "the state must be 4 (REQUEST_RATES)");
            assert.equal(buyFee.toNumber(), 0, "the buy fee must be 0");
            assert.equal(sellFee.toNumber(), 0, "the sell fee must be 0");
            assert.equal(calcTime.toNumber(), 0, "the calcTime must be 0");
            assert.equal(requestTime.toNumber(), 0, "the requestTime fee must be 0");
            assert.isAbove(deadline.toNumber(), parseInt(new Date().getTime()/1000), "the deadline must be more then now");
            assert.isAtLeast(tokenAddress.length, 40, "the tokenAddress must be a string (here) with length >= 40");
            assert.isAtLeast(withdrawWallet.length, 40, "the withdrawWallet must be a string (here) with length >= 40");
        });
    });

    context("requestRate", function() {
        beforeEach("check state", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let state = + await exchanger.getState.call();
            assert.equal(state, StateENUM.REQUEST_RATES,"Don't correct state!!")
        });

        it("payAmount == zero", async function() {
            let exchanger = await ComplexExchanger.deployed();
            

            try {
                await exchanger.requestRates();
            } catch(e) {
                return true;
            }
            
            throw new Error("Don't throw if send 0 eth!");
        });

        it("payAmount < oraclesCost", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let oraclesCost = + await exchanger.requestPrice.call();

            try {
                await exchanger.requestRates({value: oraclesCost - 100});
            } catch(e) {
                return true;
            }

            throw new Error("Don't throw if send < oraclesCost");
        });

        it("payAmount == oraclesCost", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let oraclesCost = + await exchanger.requestPrice.call();

            try {
                await exchanger.requestRates({value: oraclesCost});
            } catch(e) {
                throw new Error("throw if send == oraclesCost");
            }

            return true;
        });

        it("payAmount > oraclesCost", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let oraclesCost = + await exchanger.requestPrice.call();

            try {
                await exchanger.requestRates({value: oraclesCost + 100});
            } catch(e) {
                throw new Error("throw if send > oraclesCost");
            }

            return true;
        });
    });
});