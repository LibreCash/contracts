const
    reverter = new (require('./helpers/reverter'))(web3),
    timeMachine = new (require('./helpers/timemachine'))(web3),
    AssertTx = require('./helpers/assertTx'),
    assertTx = new AssertTx();

const truffleTestGasPrice = 100000000000,
      tokenMultiplier = Math.pow(10, 18),
      MORE_THAN_COSTS = web3.toWei(5,'ether');

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

function gasCost() {
    let
        lastBlock = web3.eth.getBlock("latest"),
        gasUsed = lastBlock.gasUsed,
        gasPrice = + web3.eth.getTransaction(lastBlock.transactions[0]).gasPrice;

    return gasUsed * gasPrice;
}

function now() {
    return web3.eth.getBlock(web3.eth.blockNumber).timestamp;
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
    

contract('ComplexExchanger', function(accounts) {
    var owner = accounts[0];
    var acc1  = accounts[1];
    var acc2  = accounts[2];
    var oracleTest = oracles[3];

    context("getState", async function() {
        var jump;

        before("init", reverter.snapshot);
        afterEach("revert", reverter.revert);
        
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
            assert.equal(state.toNumber(), StateENUM.REQUEST_RATES, "the initial state must be REQUEST_RATES");
            assert.equal(buyFee.toNumber(), exConfig.buyFee, `the buy fee must be ${exConfig.buyFee}`);
            assert.equal(sellFee.toNumber(), exConfig.sellFee, `the sell fee must be ${exConfig.sellFee}`);
            assert.equal(calcTime.toNumber(), 0, "the calcTime must be 0");
            assert.equal(requestTime.toNumber(), 0, "the requestTime fee must be 0");
            assert.equal(requestPrice.toNumber(), 0, "the initial oracle queries price must be 0");
            assert.isAbove(oracleCount.toNumber(),exConfig.MIN_READY_ORACLES, `the initial oracle count must be more than, ${exConfig.MIN_READY_ORACLES}`);
            assert.equal(tokenBalance.toNumber(), 0, "the initial token balance must be 0");
            assert.equal(readyOracles.toNumber(), 0, "the initial ready oracle count must be 0");
            assert.equal(waitingOracles.toNumber(), 0, "the initial waiting oracle count must be 0");
            assert.isAbove(deadline.toNumber(), parseInt(new Date().getTime()/1000), "the deadline must be more then now");
            assert.isTrue(web3.isAddress(tokenAddress), "the tokenAddress must be a valid address");
            assert.isTrue(web3.isAddress(withdrawWallet), "the withdrawWallet must be a valid address");

            // go for oracles
            for (var i = 0; i < oracleCount.toNumber(); i++) {
                let _oracle = await exchanger.oracles.call(i);
                assert.isAtLeast(_oracle.length, 40, "each oracle address must be a string (here) with length >= 40");
                let _oracleData = await exchanger.getOracleData.call(i);
                assert.isArray(_oracleData, "the returned oracle data must be an array");
                assert.lengthOf(_oracleData, 7, "there must be exact 7 items in the returned oracle data");
                let [_oracleAddress, _oracleName, _oracleType, _waitQuery, _updateTime, _callbackTime, _rate] = _oracleData;
                assert.equal(_oracle, _oracleAddress, "the oracle address got by oracles(i) should be equal to the one from getOracleData(i)");
                assert.isTrue(web3.isAddress(_oracle),"the oracle address must be valid");
                assert.equal((_oracleName.length - "0x".length) / 2, 32, "oracle name must be bytes32");
                assert.equal((_oracleType.length - "0x".length) / 2, 16, "oracle type must be bytes16");
                assert.equal(_waitQuery, false, "the new oracle shouldn't be waiting");
                assert.equal(_updateTime.toNumber(), 0, "the new oracle's update time should be 0");
                assert.equal(_callbackTime.toNumber(), 0, "the new oracle's update time should be 0");
                assert.equal(_rate.toNumber(), 0, "the new oracle's rate should be 0");
            }
        });

        it("(2) check PROCESSING_ORDERS", async function() {
            let 
                exchanger = await ComplexExchanger.deployed(),
                state = + await exchanger.getState.call(),
                calcTime = + await exchanger.calcTime.call();

            if (now() - calcTime > exConfig.RATE_PERIOD) {
                assert.notEqual(state, StateENUM.PROCESSING_ORDERS, 
                    "Don't correct state when calcTime > RATE_PERIOD");
                await exchanger.requestRates({value: MORE_THAN_COSTS});
                await exchanger.calcRates();
                state = + await exchanger.getState.call();
            }

            assert.equal(state, StateENUM.PROCESSING_ORDERS,"Don't correct state when calcTime < RATE_PERIOD");
        });

        it("(3) check WAIT_ORACLES", async function() {
            let exchanger = await ComplexExchanger.deployed();

            await exchanger.requestRates({value: MORE_THAN_COSTS});
            let 
                state = + await exchanger.getState.call(),
                waiting = + await exchanger.waitingOracles.call();

            if (waiting == 0) {
                assert.notEqual(state, StateENUM.WAIT_ORACLES, "Don't correct state when waitingOracles == 0");
                let oracle = await oracles[0].deployed();
                await oracle.setWaitQuery(true);

                state = + await exchanger.getState.call();
            }

            assert.equal(state, StateENUM.WAIT_ORACLES, "Don't correct state when waitingOracles != 0");
        });

        it("(4),(5) check CALC_RATES and REQUEST_RATES", async function() {
            let exchanger = await ComplexExchanger.deployed();
            await exchanger.requestRates({value: MORE_THAN_COSTS});

            let 
                state = + await exchanger.getState.call(),
                ready = + await exchanger.readyOracles.call();

            if (ready >= exConfig.MIN_READY_ORACLES) {
                assert.equal(state, StateENUM.CALC_RATES, 
                    "Don't correct state when readyOracles >= MIN_READY_ORACLES");
                for(let i=0; i < (oracles.length - exConfig.MIN_READY_ORACLES + 1); i++) {
                    let oracle = await oracles[i].deployed();
                    oracle.setRate(0);
                }

                state = + await exchanger.getState.call();
            }

            assert.equal(state, StateENUM.REQUEST_RATES, 
                "Don't correct state when readyOracles < MIN_READY_ORACLES");
        });
    });

    context("waitingOracles", function() {

        before("init", reverter.snapshot);
        afterEach("revert", reverter.revert);

        it("(1),(3) time wait < ORACLE_TIMEOUT", async function() {
            let exchanger = await ComplexExchanger.deployed();

            var requestRates = await assertTx.run(exchanger.requestRates, [{value: MORE_THAN_COSTS}]);
            assertTx.success(requestRates, "requestRates failed");
            let waiting = + await exchanger.waitingOracles.call();
            assert.equal(waiting, 0, "WaitingOracles not 0 if 0 waiting!");
            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                var setWaitQuery = await assertTx.run(oracle.setWaitQuery, [true]);
                assertTx.success(setWaitQuery);
                waiting = + await exchanger.waitingOracles.call();
                assert.equal(waiting, i + 1, `WaitingOracles not ${waiting} if ${i+1} waiting!`);
            }
        });

        it("(2) time wait > ORACLE_TIMEOUT", async function() {
            let exchanger = await ComplexExchanger.deployed();

            var requestRates = await assertTx.run(exchanger.requestRates, [{value: MORE_THAN_COSTS}]);
            assertTx.success(requestRates, "requestRates failed");
            for(let i=0; i< oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                var setWaitQuery = await assertTx.run(oracle.setWaitQuery, [true]);
                assertTx.success(setWaitQuery);
            }
            let waiting = + await exchanger.waitingOracles.call();
            assert.equal( waiting, oracles.length, "Don't equal waiting oracles!");
            await timeMachine.jump(exConfig.ORACLE_TIMEOUT + 1);

            waiting = + await exchanger.waitingOracles.call();
            assert.equal(waiting, 0, `${waiting} wait oracle when timeout!`);

            await timeMachine.jump(-exConfig.ORACLE_TIMEOUT - 1);
        });
    });

    context("readyOracles", function() {

        before("init", reverter.snapshot);
        afterEach("revert", reverter.revert);

        it("(1),(4) rate == 0 or wait == 0", async function() {
            let exchanger = await ComplexExchanger.deployed();

            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                var setRate = await assertTx.run(oracle.setRate, [0]);
                assertTx.success(setRate);
            }

            let ready = + await exchanger.readyOracles.call();
            assert.equal(ready, 0, "if rate == 0, ready oracles != 0");

            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                var setRate = await assertTx.run(oracle.setRate, [10]);
                assertTx.success(setRate);
                var setWaitQuery = await assertTx.run(oracle.setWaitQuery, [true]);
                assertTx.success(setWaitQuery);
            }

            ready = + await exchanger.readyOracles.call();
            assert.equal(ready, 0, "if wait oracle, ready oracle != 0");
        });

        it("(2) callbackTime < ORACLE_ACTUAL", async function() {
            let exchanger = await ComplexExchanger.deployed();

            var requestRates = await assertTx.run(exchanger.requestRates, [{value: MORE_THAN_COSTS}]);
            assertTx.success(requestRates, "requestRates failed");
            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                var setWaitQuery = await assertTx.run(oracle.setWaitQuery, [true]);
                assertTx.success(setWaitQuery);
                let ready = + await exchanger.readyOracles.call();
                assert.equal(ready, oracles.length - i -1, "");
            }
        });

        it("(3) callbackTime > ORACLE_ACTUAL", async function() {
            let exchanger = await ComplexExchanger.deployed();

            var requestRates = await assertTx.run(exchanger.requestRates, [{value: MORE_THAN_COSTS}]);
            assertTx.success(requestRates, "requestRates failed");
            let ready = + await exchanger.readyOracles.call();
            assert.equal(ready, oracles.length, "ready oracle don't equal count oracles");

            await timeMachine.jump(exConfig.ORACLE_ACTUAL +1);
            ready = + await exchanger.readyOracles.call();
            assert.equal(ready, 0, "ready oracles != 0, if ACTUAL timeout");

            await timeMachine.jump(-exConfig.ORACLE_ACTUAL - 1);
        });
    });

    context("buy and sell" , async function() {

        before("init", reverter.snapshot);
        after("revert", reverter.revert);

        it("(-) before all, init contracts", async function() {
            var token = await LibreCash.deployed(),
                exchanger = await ComplexExchanger.deployed();
                
            var exchanger = await ComplexExchanger.deployed(),
                state = await exchanger.getState.call(),
                requestPrice = await exchanger.requestPrice.call(),
                oracleCount = await exchanger.oracleCount.call();
            assert.equal(state.toNumber(), StateENUM.REQUEST_RATES, "the initial state must be REQUEST_RATES");
            assert.equal(requestPrice.toNumber(), 0, "the initial oracle queries price must be 0");

            var requestRates = await assertTx.run(exchanger.requestRates, [{value: MORE_THAN_COSTS}]);
            assertTx.success(requestRates, "requestRates failed");
            state = await exchanger.getState.call();

            var crTimeout = Date.now() + 1000 * 60 * 10; // 10 mins
            do {
                readyOracles = await exchanger.readyOracles.call();
                waitingOracles = await exchanger.waitingOracles.call();
                await delay(1000);
            } while ((+readyOracles != +oracleCount) && (Date.now() < crTimeout));

            assert.equal(+state, StateENUM.CALC_RATES, "the state after gathering oracle data must be CALC_RATES");
            assert.isAtLeast(readyOracles.toNumber(), 2, "ready oracle count must be at least 2");
            var CR = await assertTx.run(exchanger.calcRates, []);
            assertTx.success(CR, "calcRates tx failed");
            state = await exchanger.getState.call();
            assert.equal(+state, StateENUM.PROCESSING_ORDERS, "the state after calcRates must be PROCESSING_ORDERS");
        });

        it("(-) before sell, init contracts", async function() {
            var token = await LibreCash.deployed(),
                exchanger = await ComplexExchanger.deployed();
// EXCH BALANCE ~40
            var sellRate = +(await exchanger.sellRate.call()) / 1000;
            var weiToSendToContract = 40 * tokenMultiplier / sellRate;
            var sendTx = await assertTx.run(exchanger.refillBalance, [{ from: owner, to: exchanger.address, value: weiToSendToContract }]);
            assertTx.success(sendTx, "unsuccessful refill of exchanger balance");
// MINT 20
            var sumToMint = 20 * tokenMultiplier;
            var mint = await assertTx.run(token.mint, [owner, sumToMint]);
            assertTx.success(mint, "mint tx failed");
            var tokens = await token.balanceOf.call(owner);
            assert.equal(+tokens, sumToMint, "tokens were not minted");
        });

        it("(1-sell) try to sell more than allowance", async function() {
            var token = await LibreCash.deployed(),
                exchanger = await ComplexExchanger.deployed();
// APPROVE 10
            var approve = await assertTx.run(token.approve, [exchanger.address, 10 * tokenMultiplier]);
            assertTx.success(approve, "approve tx failed");
// SELL 20
            var sellTx = await assertTx.run(exchanger.sellTokens, [owner, 20 * tokenMultiplier]);
// FAIL ?
            assertTx.fail(sellTx, "Selling more tokens than allowed shall fail");            
        });

        it("(2-sell) try to sell more than user has", async function() {
            var token = await LibreCash.deployed(),
                exchanger = await ComplexExchanger.deployed();
// USER BALANCE 20
// APPROVE 20
            var allowanceToSet = 20 * tokenMultiplier;
            var approve = await assertTx.run(token.approve, [exchanger.address, allowanceToSet, {from: owner} ]);
            assertTx.success(approve, "approve tx failed");
            var allowance = await token.allowance.call(owner, exchanger.address);
            assert.equal(allowanceToSet, allowance, "error setting allowance");
// SELL 40
            var sellTx = await assertTx.run(exchanger.sellTokens, [owner, 40 * tokenMultiplier]);
// FAIL ?
            assertTx.fail(sellTx, "Selling more tokens than user has shall fail");            
        });

        it("(3-sell) try to sell tokens equiv. to less than 1 wei", async function() {
            var token = await LibreCash.deployed(),
                exchanger = await ComplexExchanger.deployed();
// USER BALANCE 20
// APPROVE 20
// SELL 1 / tokenMultiplier
            var sellTx = await assertTx.run(exchanger.sellTokens, [owner, 1]);
// FAIL ?
            assertTx.fail(sellTx, "Selling minimal count of tokens shall result in 0 eth and revert");            
        });

        it("(4-sell) sell 10 tokens", async function() {
            var token = await LibreCash.deployed(),
                exchanger = await ComplexExchanger.deployed();
// EXVHANGER BALANCE ~40
// USER BALANCE 20
// APPROVE 20
// SELL 10
            var sumToSell = 10 * tokenMultiplier;
            var tokensBefore = await token.balanceOf.call(owner);
            var sellTx = await assertTx.run(exchanger.sellTokens, [owner, sumToSell]);
            assertTx.success(sellTx, "Basic sell - shall be success");   
            var tokensAfter = await token.balanceOf.call(owner);
            assert.equal(+tokensBefore - +tokensAfter, sumToSell, "tokens were not subtracted from balance");        
        });

        it("(5-sell) sell 40 tokens - more than exch. has", async function() {
            var token = await LibreCash.deployed(),
                exchanger = await ComplexExchanger.deployed();
// EXCHANGER BALANCE ~30
// MINT 20
            var sumToMint = 20 * tokenMultiplier;
            var tokensBefore = await token.balanceOf.call(owner);
            var mint = await assertTx.run(token.mint, [owner, sumToMint]);
            assertTx.success(mint, "mint tx failed");
            var tokensAfter = await token.balanceOf.call(owner);
            assert.equal(+tokensAfter - +tokensBefore, sumToMint, "tokens were not minted");
// USER BALANCE 30
// APPROVE 40
            var allowanceToSet = 40 * tokenMultiplier;
            var approve = await assertTx.run(token.approve, [exchanger.address, allowanceToSet, {from: owner} ]);
            assertTx.success(approve, "approve tx failed");
            var allowance = await token.allowance.call(owner, exchanger.address);
            assert.equal(allowanceToSet, allowance, "error setting allowance");
// SELL 40
            var sumToSell = 40 * tokenMultiplier;
            var tokensBefore = await token.balanceOf.call(owner);
            var balanceExchanger = +web3.eth.getBalance(exchanger.address);
            var sellTx = await assertTx.run(exchanger.sellTokens, [owner, sumToSell]);
            assertTx.success(sellTx, "Basic sell - shall be success");
            var tokensAfter = await token.balanceOf.call(owner);
            var sellPrice = +await exchanger.sellRate.call();
            assert.equal(+tokensBefore - +tokensAfter, 30 * tokenMultiplier,"balance change must be below tokens we tried to sell");
// EXCH BALANCE ~0
            balanceExchanger = +web3.eth.getBalance(exchanger.address);
            assert.equal(balanceExchanger, 0, "exchanger balance must be 0");
        });

        it("(3-buy) buy more tokens than exch. has", async function() {
            var exchanger = await ComplexExchanger.deployed(),
                token = await LibreCash.deployed(),
                buyFee = await exchanger.buyFee.call(),
                sellFee = await exchanger.sellFee.call(),
                tokenBalance = await exchanger.tokenBalance.call(),
                buyRate = (await exchanger.buyRate.call()) / 1000;

            assert.isAbove(+tokenBalance, 0, "the exchanger token balance must not be 0 now");  
            var tokensToBuy = +tokenBalance * 2;

            var weiToSend = tokensToBuy / buyRate,
                ethToSend = web3.fromWei(weiToSend, 'ether'),
                balanceBefore = web3.eth.getBalance(owner).toNumber();
            
            var buyTx = await assertTx.run(exchanger.buyTokens, [owner, { from: owner, value: weiToSend }]);
            assertTx.success(buyTx, "buyTokens tx failed");
            var weiUsedForGas = truffleTestGasPrice * buyTx.receipt.gasUsed;
            var balanceDelta = balanceBefore - +web3.eth.getBalance(owner);
            var balanceDeltaNet = balanceDelta - weiUsedForGas;

            assert.isAbove(balanceDelta, 0, "balance delta must be positive - very strange if ever thrown");
            var boughtTokens = await token.balanceOf.call(owner);

            assert.isBelow(Math.abs(balanceDeltaNet * buyRate - +boughtTokens), 10000000, "token count doesn't match sent ether multiplied by rate");
        });

        it("(4-buy) buy all tokens from exchanger", async function() {
            var exchanger = await ComplexExchanger.deployed(),
                token = await LibreCash.deployed(),
                buyFee = await exchanger.buyFee.call(),
                sellFee = await exchanger.sellFee.call(),
                buyRate = (await exchanger.buyRate.call()) / 1000;
            var accTokensBefore = (await token.balanceOf.call(owner)) / tokenMultiplier;
            var sumToMint = 1000 * tokenMultiplier;
            var mint = await assertTx.run(token.mint, [exchanger.address, sumToMint]);
            assertTx.success(mint, "mint tx failed");
            var tokenBalance = await exchanger.tokenBalance.call();
            assert.equal(+tokenBalance, sumToMint, "the token balance after mint is not valid");  

            var tokensToBuy = sumToMint,
                weiToSend = tokensToBuy / buyRate + 100000, // 100000 wei to fill possible rounding mistakes
                ethToSend = web3.fromWei(weiToSend, 'ether'),
                balanceBefore = +web3.eth.getBalance(owner);
            var buyTx = await assertTx.run(exchanger.buyTokens, [owner, { from: owner, value: weiToSend }]);
            assertTx.success(buyTx, "buyTokens tx failed");

            var zeroBalance = balanceBefore - +web3.eth.getBalance(owner) - weiToSend -
                truffleTestGasPrice * buyTx.receipt.gasUsed;
            assert.isBelow(Math.abs(zeroBalance), 1000000, "ether sent doesn't fit the balance changed");

            var accTokensAfter = (await token.balanceOf.call(owner)) / tokenMultiplier,
                exchTokensAfter = (await exchanger.tokenBalance.call()) / tokenMultiplier;
            assert.equal(exchTokensAfter, 0, "exchanger token balance must be 0 now");
            assert.isBelow(ethToSend * buyRate - (accTokensAfter - accTokensBefore), 0.0000001, "token count doesn't match sent ether multiplied by rate");
        });

        it("(2-buy) buy tokens, no token balance -> revert", async function() {
            var exchanger = await ComplexExchanger.deployed(),
                token = await LibreCash.deployed(),
                exchangerTokenBalance = await exchanger.tokenBalance.call();;
            assert.equal(+exchangerTokenBalance, 0, "exchanger token balance must be 0 now");

            var ethToSend = 1,
                weiToSend = web3.toWei(ethToSend, 'ether');  

            var buyTx = await assertTx.run(exchanger.buyTokens, [owner, { from: owner, value: weiToSend }]);
            assertTx.fail(buyTx, "buyTokens tx with zero exchanger balance succeeded - bad");
        });

        it("(1-buy) buy 0 tokens -> revert", async function() {
            var exchanger = await ComplexExchanger.deployed(),
                token = await LibreCash.deployed();
            var sumToMint = 1000 * tokenMultiplier;
            var mint = await assertTx.run(token.mint, [exchanger.address, sumToMint]);
            assertTx.success(mint, "mint tx failed");
            var tokenBalance = await exchanger.tokenBalance.call();
            assert.equal(+tokenBalance, sumToMint, "the exchanger token balance after mint is not valid");  

            var ethToSend = 0,
                weiToSend = 0;

            var buyTx = await assertTx.run(exchanger.buyTokens, [owner, { from: owner, value: weiToSend }]);
            assertTx.fail(buyTx, "buyTokens tx with zero eth succeeded - bad");
        });

        it("(5) buy tokens for 1 eth", async function() {
            var exchanger = await ComplexExchanger.deployed(),
                token = await LibreCash.deployed(),
                buyFee = await exchanger.buyFee.call(),
                sellFee = await exchanger.sellFee.call(),
                buyRate = (await exchanger.buyRate.call()) / 1000;
            var accTokensBefore = (await token.balanceOf.call(owner)) / tokenMultiplier;

            var tokenBalance = await exchanger.tokenBalance.call();
            assert.isAbove(+tokenBalance, 0, "the exchanger token balance must be above 0 now");  

            var ethToSend = 1,
                weiToSend = web3.toWei(ethToSend, 'ether'),
                balanceBefore = +web3.eth.getBalance(owner);
            var buyTx = await assertTx.run(exchanger.buyTokens, [owner, { from: owner, value: weiToSend }]);
            assertTx.success(buyTx, "buyTokens tx failed");
            
            var zeroBalance = balanceBefore - +web3.eth.getBalance(owner) - weiToSend -
                truffleTestGasPrice * buyTx.receipt.gasUsed;
            assert.isBelow(Math.abs(zeroBalance), 100000, "ether sent doesn't fit the balance changed");

            var accTokensAfter = (await token.balanceOf.call(owner)) / tokenMultiplier;

            assert.equal(ethToSend * buyRate, accTokensAfter - accTokensBefore, "token count doesn't match sent ether multiplied by rate");
        });
    });

    context("requestRate", function() {
        var jump;

        before("init", async function() {
            let exchanger = await ComplexExchanger.deployed();

            var requestRates = await assertTx.run(exchanger.requestRates, [{from: acc1, value: MORE_THAN_COSTS}]);
            assertTx.success(requestRates, "requestRates tx falls");
            jump = Math.max(exConfig.ORACLE_ACTUAL, exConfig.ORACLE_TIMEOUT);
            await timeMachine.jump(jump + 1);
            
            let state = + await exchanger.getState.call();
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

            var requestRates = await assertTx.run(exchanger.requestRates, [{value: oraclesCost}]);
            assertTx.success(requestRates, "requestRates failed");
        });

        it("(3) payAmount > oraclesCost", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let oraclesCost = + await exchanger.requestPrice.call();
            let before = + web3.eth.getBalance(owner);

            var requestRates = await assertTx.run(exchanger.requestRates, [{value: oraclesCost + 10000000}]);
            assertTx.success(requestRates, "requestRates failed with value: oraclesCost + 10000000");

            let after = + web3.eth.getBalance(owner);
                weiUsed = gasCost();

            assert.isBelow((before - after) - weiUsed - oraclesCost, 100000, "we didn't get back oversent ether");
        });
    });

    context("calcRate", function() {
        var oraclesDeployed = [];

        before("check state", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let state = + await exchanger.getState.call();

            if (state != StateENUM.CALC_RATES) {
                var requestRates = await assertTx.run(exchanger.requestRates, [{value: MORE_THAN_COSTS}]);
                assertTx.success(requestRates, "requestRates failed");
                state = + await exchanger.getState.call();
            }

            assert.equal(state, StateENUM.CALC_RATES,"Don't correct state!!");

            reverter.snapshot((e) => {
                if (e != undefined)
                    console.log(e);
            });
        });

        afterEach("revert", reverter.revert);

        it("(1) validOracles < MIN", async function() {
            let exchanger = await ComplexExchanger.deployed();
            for (let i = 0; i < exConfig.MIN_READY_ORACLES; i++) {
                let oracle = await oracles[i].deployed();
                var setRate = await assertTx.run(oracle.setRate, [exConfig.MIN_RATE - 1]);
                assertTx.success(setRate, "oracle.setRate(MIN_RATE - 1) failed");
            }

            var calcRates = await assertTx.run(exchanger.calcRates, []);
            assertTx.fail(calcRates, "calcRates shall fail when we have MIN_RATE - 1");
            
            for (let i = 0; i < exConfig.MIN_READY_ORACLES; i++) {
                let oracle = await oracles[i].deployed();
                var setRate = await assertTx.run(oracle.setRate, [exConfig.MAX_RATE + 1]);
                assertTx.success(setRate, "oracle.setRate(MIN_RATE - 1) failed");
            }

            var calcRates = await assertTx.run(exchanger.calcRates, []);
            assertTx.fail(calcRates, "calcRates shall fail when we have MAX_RATE + 1");
        });

        it("(2) validOracles > min", async function() {
            let exchanger = await ComplexExchanger.deployed();

            var calcRates = await assertTx.run(exchanger.calcRates, []);
            assertTx.success(calcRates, "Error if calcRate with valid oracles");

            let max, min;
            for(let i = 0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                let rate = + await oracle.rate.call();
                if (rate < exConfig.MIN_RATE || rate > exConfig.MAX_RATE)
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
                await exchanger.refillBalance({value: MORE_THAN_COSTS});
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

            assert.isTrue(wBalanceBefore < wBalanceAfter, "Balance wallet don't changed");
            assert.equal(eBalanceAfter, 0, "Withdraw don't all balance");
        });
    });
});