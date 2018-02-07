const
    Reverter = require('./helpers/reverter'),
    reverter = new Reverter(web3),
    TimeMachine = require('./helpers/timemachine'),
    timeMachine = new TimeMachine(web3);

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
        
        it("get initial states", async function() {
            var exchanger = await ComplexExchanger.deployed();
            var state = await exchanger.getState.call();
            var buyFee = await exchanger.buyFee.call();
            var sellFee = await exchanger.sellFee.call();
            var deadline = await exchanger.deadline.call();
            var calcTime = await exchanger.calcTime.call();
            var requestTime = await exchanger.requestTime.call();
            var requestPrice = await exchanger.requestPrice.call();
            var oracleCount = await exchanger.oracleCount.call();
            //var tokenBalance = await exchanger.tokenBalance.call();
            var readyOracles = await exchanger.readyOracles.call();
            var waitingOracles = await exchanger.waitingOracles.call();
            var tokenAddress = await exchanger.tokenAddress.call();
            var withdrawWallet = await exchanger.withdrawWallet.call();
            assert.equal(state.toNumber(), 4, "the state must be 4 (REQUEST_RATES)");
            assert.equal(buyFee.toNumber(), 0, "the buy fee must be 0");
            assert.equal(sellFee.toNumber(), 0, "the sell fee must be 0");
            assert.equal(calcTime.toNumber(), 0, "the calcTime must be 0");
            assert.equal(requestTime.toNumber(), 0, "the requestTime fee must be 0");
            assert.equal(requestPrice.toNumber(), 0, "the initial oracle queries price must be 0");
            assert.isAbove(oracleCount.toNumber(), 2, "the initial oracle count must be more than, for example, 2");
            //assert.equal(tokenBalance.toNumber(), 0, "the initial token balance must be 0");
            assert.equal(readyOracles.toNumber(), 0, "the initial ready oracle count must be 0");
            assert.equal(waitingOracles.toNumber(), 0, "the initial waiting oracle count must be 0");
            assert.isAbove(deadline.toNumber(), parseInt(new Date().getTime()/1000), "the deadline must be more then now");
            assert.isAtLeast(tokenAddress.length, 40, "the tokenAddress must be a string (in the test) with length >= 40");
            assert.isAtLeast(withdrawWallet.length, 40, "the withdrawWallet must be a string (in the test) with length >= 40");
            console.log(tokenAddress);

            // go for oracles
            for (var i = 0; i < oracleCount.toNumber(); i++) {
                let _oracle = await exchanger.oracles.call(i);
                assert.isAtLeast(_oracle.length, 40, "each oracle address must be a string (here) with length >= 40");
                let _oracleData = await exchanger.getOracleData.call(i);
                assert.isArray(_oracleData, "the returned oracle data must be an array");
                assert.lengthOf(_oracleData, 7, "there must be exact 7 items in the returned oracle data");
                let [_oracleAddress, _oracleName, _oracleType, _waitQuery, _updateTime, _callbackTime, _rate] = _oracleData;
                assert.equal(_oracle, _oracleAddress, "the oracle address got by oracles(i) should be equal to the one from getOracleData(i)");
                assert.equal((_oracleName.length - "0x".length) / 2, 32, "oracle name must be bytes32");
                assert.equal((_oracleType.length - "0x".length) / 2, 16, "oracle type must be bytes16");
                assert.equal(_waitQuery, false, "the new oracle shouldn't be waiting");
                assert.equal(_updateTime.toNumber(), 0, "the new oracle's update time should be 0");
                assert.equal(_callbackTime.toNumber(), 0, "the new oracle's update time should be 0");
                assert.equal(_rate.toNumber(), 0, "the new oracle's rate should be 0");
            }
        });
    });

    context("requestRate", function() {

        before("init", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let state = + await exchanger.getState.call();
            assert.equal(state, StateENUM.REQUEST_RATES,"Don't correct state!!");
            
            reverter.snapshot((e) => {
                if (e != undefined)
                    console.log(e);
            });
        });

        afterEach("revert", function() {
            reverter.revert((e) => {
                if (e != undefined)
                    console.log(e);
            });
        });

        it("(1) payAmount < oraclesCost", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let oraclesCost = + await exchanger.requestPrice.call();
            try {
                await exchanger.requestRates();
            } catch(e) {
                try {
                    await exchanger.requestRates({value: oraclesCost/2});
                } catch(e) {
                    return true;
                }
            }

            if (oraclesCost > 0)
                throw new Error("Don't throw if send < oraclesCost");
        });

        it("(2) payAmount == oraclesCost", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let oraclesCost = + await exchanger.requestPrice.call();

            try {
                await exchanger.requestRates({value: oraclesCost});
            } catch(e) {
                throw new Error("throw if send == oraclesCost");
            }

            return true;
        });

        it("(3) payAmount > oraclesCost", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let oraclesCost = + await exchanger.requestPrice.call();
            let before = + web3.eth.getBalance(owner);

            try {
                await exchanger.requestRates({value: oraclesCost + 100});
            } catch(e) {
                throw new Error("throw if send > oraclesCost");
            }
            let after = + web3.eth.getBalance(owner);

            //assert.equal(before, after + oraclesCost, "Balance not equal!!");
        });
    });

    context("calcRate", function() {

        beforeEach("check state", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let state = + await exchanger.getState.call();
            assert.equal(state, StateENUM.CALC_RATES,"Don't correct state!!");
        });

        it("readyOracles < MIN", async function() {
            let exchanger = await ComplexExchanger.deployed();
            //??
        });
    });

    context("withdrawReserve", function() {
        var jump;

        before("check state", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let deadline = + await exchanger.deadline.call();

            jump = deadline - web3.eth.getBlock(web3.eth.blockNumber).timestamp;
            await timeMachine.jump(jump);

            let state = + await exchanger.getState.call();
            assert.equal(state, StateENUM.LOCKED,"Don't correct state!!");
        });

        after("clear", async function() {
            await timeMachine.jump(-jump);
        });

        it("(1) Don't withdraw if not wallet", async function() {
            let exchanger = await ComplexExchanger.deployed();

            try {
                await exchanger.withdrawReserve({from: acc1});
            } catch(e) {
                return true;
            }

            throw new Error("Not wallet withdraw reserve!!");
        });

        it("(2) withdraw if call wallet", async function() {
            let exchanger = await ComplexExchanger.deployed();

            let eBalanceBefore = web3.eth.getBalance(exchanger.address);
            if (eBalanceBefore == 0) {
                await exchanger.refillBalance({value: web3.toWei(5,'ether')});
                eBalanceBefore = web3.eth.getBalance(exchanger.address);
            }

            let wBalanceBefore = web3.eth.getBalance(owner);
            try {
                await exchanger.withdrawReserve();
            } catch(e) {
                throw new Error("Wallet don't withdraw reserve!!");
            }

            let eBalanceAfter = web3.eth.getBalance(exchanger.address);
            let wBalanceAfter = web3.eth.getBalance(owner);

            assert.isTrue(eBalanceBefore > eBalanceAfter, "Balance don't changed");
            assert.equal(eBalanceAfter, 0, "Withdraw don't all balance");
        })
    });
});