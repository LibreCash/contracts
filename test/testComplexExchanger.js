const
    Reverter = require('./helpers/reverter'),
    reverter = new Reverter(web3),
    TimeMachine = require('./helpers/timemachine'),
    timeMachine = new TimeMachine(web3);

const truffleTestGasPrice = 100000000000,
      tokenMultiplier = Math.pow(10, 18);

var ComplexExchanger = artifacts.require("ComplexExchanger");
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

const 
    minutes = 60,
    ORACLE_ACTUAL = 10 * minutes,
    ORACLE_TIMEOUT = 10 * minutes,
    RATE_PERIOD = 10 * minutes,
    MIN_READY_ORACLES = 2,
    REVERSE_PERCENT = 100,
    RATE_MULTIPLIER = 1000,
    MAX_RATE = 5000 * RATE_MULTIPLIER,
    MIN_RATE = 100 * RATE_MULTIPLIER;

contract('ComplexExchanger', function(accounts) {
    var owner = accounts[0];
    var acc1  = accounts[1];
    var acc2  = accounts[2];
    var oracleTest = oracles[3];

    context("getState", async function() {

        before("init", async function() {
            let exchanger = await ComplexExchanger.deployed();
            oracles.forEach(async oracle => await oracle.deployed());
        });
        
        it("get initial states", async function() {
            var exchanger = await ComplexExchanger.deployed(),
                state = await exchanger.getState.call(),
                buyFee = await exchanger.buyFee.call(),
                sellFee = await exchanger.sellFee.call(),
                deadline = await exchanger.deadline.call(),
                calcTime = await exchanger.calcTime.call(),
                requestTime = await exchanger.requestTime.call(),
                requestPrice = await exchanger.requestPrice.call(),
                oracleCount = await exchanger.oracleCount.call(),
                tokenBalance = await exchanger.tokenBalance.call(),
                readyOracles = await exchanger.readyOracles.call(),
                waitingOracles = await exchanger.waitingOracles.call(),
                tokenAddress = await exchanger.tokenAddress.call(),
                withdrawWallet = await exchanger.withdrawWallet.call();
            assert.equal(state.toNumber(), 4, "the initial state must be 4 (REQUEST_RATES)");
            assert.equal(buyFee.toNumber(), 0, "the buy fee must be 0");
            assert.equal(sellFee.toNumber(), 0, "the sell fee must be 0");
            assert.equal(calcTime.toNumber(), 0, "the calcTime must be 0");
            assert.equal(requestTime.toNumber(), 0, "the requestTime fee must be 0");
            assert.equal(requestPrice.toNumber(), 0, "the initial oracle queries price must be 0");
            assert.isAbove(oracleCount.toNumber(), 2, "the initial oracle count must be more than, for example, 2");
            assert.equal(tokenBalance.toNumber(), 0, "the initial token balance must be 0");
            assert.equal(readyOracles.toNumber(), 0, "the initial ready oracle count must be 0");
            assert.equal(waitingOracles.toNumber(), 0, "the initial waiting oracle count must be 0");
            assert.isAbove(deadline.toNumber(), parseInt(new Date().getTime()/1000), "the deadline must be more then now");
            assert.isAtLeast(tokenAddress.length, 40, "the tokenAddress must be a string (in the test) with length >= 40");
            assert.isAtLeast(withdrawWallet.length, 40, "the withdrawWallet must be a string (in the test) with length >= 40");

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

    context("buy/sell", async function() {
        beforeEach(async function() {
            var token = await LibreCash.deployed(),
                exchanger = await ComplexExchanger.deployed();
            var sumToMint = 1000 * tokenMultiplier;
            var mint = await token.mint(exchanger.address, sumToMint);
            assert.equal(mint.receipt.status, 1, "mint tx failed");
    
            var tokenBalance = await exchanger.tokenBalance.call();
            assert.equal(tokenBalance.toNumber(), sumToMint, "the token balance after mint is not valid");               
            var exchanger = await ComplexExchanger.deployed(),
                state = await exchanger.getState.call(),
                requestPrice = await exchanger.requestPrice.call(),
                oracleCount = await exchanger.oracleCount.call();
            assert.equal(state.toNumber(), 4, "the initial state must be 4 (REQUEST_RATES)");
            assert.equal(requestPrice.toNumber(), 0, "the initial oracle queries price must be 0");
    
            var RR = await exchanger.requestRates();
            assert.equal(RR.receipt.status, 1, "requestRates tx failed");
            console.log("[test] successful requestRates()");
            state = await exchanger.getState.call();
            //next line for real oracles
            //assert.equal(state.toNumber(), 2, "the state after requestRates must be 2 (WAIT_ORACLES)");
    
            var crTimeout = Date.now() + 1000 * 60 * 10; // 10 mins
            do {
                readyOracles = await exchanger.readyOracles.call();
                waitingOracles = await exchanger.waitingOracles.call();
                await delay(1000);
                console.log("delayed");
            } while ((readyOracles.toNumber() != oracleCount.toNumber()) && (Date.now() < crTimeout));
    
            assert.equal(state.toNumber(), 3, "the state after gathering oracle data must be 3 (CALC_RATES)");
            assert.isAtLeast(readyOracles.toNumber(), 2, "ready oracle count must be at least 2");
            var CR = await exchanger.calcRates();
            assert.equal(CR.receipt.status, 1, "calcRates tx failed");
            state = await exchanger.getState.call();
            assert.equal(state.toNumber(), 1, "the state after calcRates must be 1 (PROCESSING_ORDERS)");
        });
    
        it("buy tokens", async function() {
            var exchanger = await ComplexExchanger.deployed(),
                token = await LibreCash.deployed(),
                buyFee = await exchanger.buyFee.call(),
                sellFee = await exchanger.sellFee.call(),
                buyRate = (await exchanger.buyRate.call()) / 1000;
            var ethToSend = 1,
                weiToSend = web3.toWei(ethToSend, 'ether'),
                balanceBefore = +web3.eth.getBalance(owner);
            var buyTx = await exchanger.buyTokens(owner, { from: owner, value: weiToSend });
            assert.equal(buyTx.receipt.status, 1, "buyTokens tx failed");
            // this is the gas only when exchanger doesn't refund
            var zeroBalance = balanceBefore - +web3.eth.getBalance(owner) - weiToSend -
                truffleTestGasPrice * buyTx.receipt.gasUsed;
            // if zeroBalance is below 100000, it is insufficient
            assert.isBelow(Math.abs(zeroBalance), 100000, "ether sent doesn't fit the balance changed");

            var boughtTokens = (await token.balanceOf.call(owner)) / tokenMultiplier;

            console.log(`we sent ${ethToSend} ether`);
            console.log(`rate was ${buyRate}`);
            console.log(`we got ${boughtTokens} tokens`);
            console.log(`shall be ${ethToSend} * ${buyRate} == ${boughtTokens}`);
            assert.equal(ethToSend * buyRate, boughtTokens, "token count doesn't match sent ether multiplied by rate");
        });
    
        it("buy more tokens than exch. has", async function() {
            var exchanger = await ComplexExchanger.deployed(),
                token = await LibreCash.deployed(),
                buyFee = await exchanger.buyFee.call(),
                sellFee = await exchanger.sellFee.call(),
                tokenBalance = await exchanger.tokenBalance.call(),
                buyRate = (await exchanger.buyRate.call()) / 1000,
                exchangerBalance = (await token.balanceOf.call(exchanger.address)) / tokenMultiplier;
            // exchangerBalance shall be 1000 tokens now, let's try to buy 1500 tokens
            var tokensToBuy = 1500,
                ethToSend = tokensToBuy / buyRate,
                weiToSend = web3.toWei(ethToSend, 'ether'),
                balanceBefore = web3.eth.getBalance(owner).toNumber();
            
            var buyTx = await exchanger.buyTokens(owner, { from: owner, value: weiToSend });
            assert.equal(buyTx.receipt.status, 1, "buyTokens tx failed");
            var weiUsedForGas = truffleTestGasPrice * buyTx.receipt.gasUsed;
            var balanceDelta = balanceBefore - +web3.eth.getBalance(owner);
            var balanceDeltaNet = balanceDelta - weiUsedForGas;

            assert.isAbove(balanceDelta, 0, "balance delta must be positive - very strange if ever thrown");
            var boughtTokens = await token.balanceOf.call(owner);

            console.log(`we sent ${ethToSend} ether`);
            console.log(`but balance change is ${balanceDeltaNet / tokenMultiplier}`);
            console.log(`rate was ${buyRate}`);
            console.log(`so we got ${+boughtTokens / tokenMultiplier} tokens`);
            console.log(`shall be ${web3.fromWei(balanceDeltaNet, 'ether')} * ${buyRate} == ${+boughtTokens / tokenMultiplier}`);
            // if the difference is below 10000000, it is insufficient (for example gas price is about 5384400000000000)
            assert.isBelow(Math.abs(balanceDeltaNet * buyRate - +boughtTokens), 10000000, "token count doesn't match sent ether multiplied by rate");
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
        var oraclesDeployed = [];

        before("check state", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let state = + await exchanger.getState.call();

            if (state != StateENUM.CALC_RATES) {
                await exchanger.requestRates({value: web3.toWei(5,'ether')});
                state = + await exchanger.getState.call();
            }

            assert.equal(state, StateENUM.CALC_RATES,"Don't correct state!!");

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

        it("(1) validOracles < MIN", async function() {
            let exchanger = await ComplexExchanger.deployed();
            for (let i = 0; i < MIN_READY_ORACLES; i++) {
                let oracle = await oracles[i].deployed();
                await oracle.setRate(MIN_RATE - 1);
            }

            try {
                await exchanger.calcRates();
            } catch(e) {
                for (let i = 0; i < MIN_READY_ORACLES; i++) {
                    let oracle = await oracles[i].deployed();
                    await oracle.setRate(MAX_RATE + 1);
                }

                try {
                    await exchanger.calcRates();
                } catch(e) {
                    return true;
                }
            }

            throw new Error("calcRate call without revert if count valid oracles < MIN");
        });

        it("(2) validOracles > min", async function() {
            let exchanger = await ComplexExchanger.deployed();

            try {
                await exchanger.calcRates();
            } catch(e) {
                throw new Error("Error if calcRate with valid oracles");
            }

            let max, min;
            for(let i = 0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                let rate = + await oracle.rate.call();
                if (rate < MIN_RATE || rate > MAX_RATE)
                    continue;

                max = (max === undefined) ? rate : Math.max(max,rate);
                min = (min === undefined) ? rate : Math.min(min,rate);
            }

            let 
                buyFee = + await exchanger.buyFee.call(),
                sellFee = + await exchanger.sellFee.call(),
                buyRate = + await exchanger.buyRate.call(),
                sellRate = + await exchanger.sellRate.call();

            calcBuyRate = min - min * buyFee/100/REVERSE_PERCENT;
            calcSellRate = max + max * sellFee/100/REVERSE_PERCENT;

            assert.equal(calcBuyRate, buyRate, "Don't equal calculate and return buyRate");
            assert.equal(calcSellRate, sellRate , "Don't equal calculate and return sellRate");
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
        });
    });
});