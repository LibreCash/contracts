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

async function runTx(_func, _args) {
    var funcRes;
    try {
        funcRes = await _func(..._args);
    } catch(e) {
        if (e.toString().indexOf("VM Exception while processing transaction: revert") != -1) {
            funcRes = { receipt: {status: 0 }};
        } else {
            throw new Error(e.toString());
        }
    }
    return funcRes;
}

function assertSuccessfulTx(tx, msg) {
    return assert.equal(tx.receipt.status, 1, msg);
}

function assertUnsuccessfulTx(tx, msg) {
    return assert.equal(tx.receipt.status, 0, msg);
}

function getWeiUsedForGas() {
    let
        lastBlock = web3.eth.getBlock("latest"),
        gasUsed = lastBlock.gasUsed,
        gasPrice = + web3.eth.getTransaction(lastBlock.transactions[0]).gasPrice;

    return gasUsed * gasPrice;
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
            assert.equal(state.toNumber(), StateENUM.REQUEST_RATES, "the initial state must be REQUEST_RATES");
            assert.equal(buyFee.toNumber(), 250, "the buy fee must be 250");
            assert.equal(sellFee.toNumber(), 250, "the sell fee must be 250");
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

    context("waitingOracles", function() {
        before("init", function() {
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

        it("(1),(3) time wait < ORACLE_TIMEOUT", async function() {
            let exchanger = await ComplexExchanger.deployed();

            await exchanger.requestRates({value: web3.toWei(5,'ether')});
            let waiting = + await exchanger.waitingOracles.call();
            assert.equal(waiting, 0, "WaitingOracles not 0 if 0 waiting!");
            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                await oracle.setWaitQuery(true);
                waiting = + await exchanger.waitingOracles.call();
                assert.equal(waiting, i + 1, `WaitingOracles not ${waiting} if ${i+1} waiting!`);
            }
            console.log(waiting);
        });

        it("(2) time wait > ORACLE_TIMEOUT", async function() {
            let exchanger = await ComplexExchanger.deployed();

            await exchanger.requestRates({value: web3.toWei(5,'ether')});
            for(let i=0; i< oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                await oracle.setWaitQuery(true);
            }
            let waiting = + await exchanger.waitingOracles.call();
            assert.equal( waiting, oracles.length, "Don't equal waiting oracles!");
            await timeMachine.jump(ORACLE_TIMEOUT + 1);

            waiting = + await exchanger.waitingOracles.call();
            assert.equal(waiting, 0, `${waiting} wait oracle when timeout!`);

            await timeMachine.jump(-ORACLE_TIMEOUT - 1);
        });
    });

    context("readyOracles", function() {

        before("init", function() {
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

        it("(1),(4) rate == 0 or wait == 0", async function() {
            let exchanger = await ComplexExchanger.deployed();

            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                await oracle.setRate(0);
            }

            let ready = + await exchanger.readyOracles.call();
            assert.equal(ready, 0, "if rate == 0, ready oracles != 0");

            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                await oracle.setRate(10);
                await oracle.setWaitQuery(true);
            }

            ready = + await exchanger.readyOracles.call();
            assert.equal(ready, 0, "if wait oracle, ready oracle != 0");
        });

        it("(2) callbackTime < ORACLE_ACTUAL", async function() {
            let exchanger = await ComplexExchanger.deployed();

            await exchanger.requestRates({value: web3.toWei(5,'ether')});
            for(let i=0; i < oracles.length; i++) {
                let oracle = await oracles[i].deployed();
                await oracle.setWaitQuery(true);
                let ready = + await exchanger.readyOracles.call();
                assert.equal(ready, oracles.length - i -1, "");
            }
        });

        it("(3) callbackTime > ORACLE_ACTUAL", async function() {
            let exchanger = await ComplexExchanger.deployed();

            await exchanger.requestRates({value: web3.toWei(5,'ether')});
            let ready = + await exchanger.readyOracles.call();
            assert.equal(ready, oracles.length, "ready oracle don't equal count oracles");

            await timeMachine.jump(ORACLE_ACTUAL +1);
            ready = + await exchanger.readyOracles.call();
            assert.equal(ready, 0, "ready oracles != 0, if ACTUAL timeout");

            await timeMachine.jump(-ORACLE_ACTUAL - 1);
        });
    });

    context("buy and sell" , async function() {
        context("sell", async function() {
            it("(-) before buy OR sell, init contracts", async function() {
                var token = await LibreCash.deployed(),
                    exchanger = await ComplexExchanger.deployed();
                 
                var exchanger = await ComplexExchanger.deployed(),
                    state = await exchanger.getState.call(),
                    requestPrice = await exchanger.requestPrice.call(),
                    oracleCount = await exchanger.oracleCount.call();
                assert.equal(state.toNumber(), StateENUM.REQUEST_RATES, "the initial state must be REQUEST_RATES");
                assert.equal(requestPrice.toNumber(), 0, "the initial oracle queries price must be 0");
        
                var RR = await runTx(exchanger.requestRates, []);
                assertSuccessfulTx(RR, "requestRates tx failed");
                console.log("[test] successful requestRates()");
                state = await exchanger.getState.call();
                //next line for real oracles
                //assert.equal(state.toNumber(), StateENUM.WAIT_ORACLES, "the state after requestRates must be WAIT_ORACLES");
        
                var crTimeout = Date.now() + 1000 * 60 * 10; // 10 mins
                do {
                    readyOracles = await exchanger.readyOracles.call();
                    waitingOracles = await exchanger.waitingOracles.call();
                    await delay(1000);
                    console.log("delayed");
                } while ((readyOracles.toNumber() != oracleCount.toNumber()) && (Date.now() < crTimeout));
        
                assert.equal(state.toNumber(), StateENUM.CALC_RATES, "the state after gathering oracle data must be CALC_RATES");
                assert.isAtLeast(readyOracles.toNumber(), 2, "ready oracle count must be at least 2");
                var CR = await runTx(exchanger.calcRates, []);
                assertSuccessfulTx(CR, "calcRates tx failed");
                state = await exchanger.getState.call();
                assert.equal(state.toNumber(), StateENUM.PROCESSING_ORDERS, "the state after calcRates must be PROCESSING_ORDERS");
            });
    
            it("(-) before sell, init contracts", async function() {
                var token = await LibreCash.deployed(),
                    exchanger = await ComplexExchanger.deployed();
    // EXCH BALANCE ~40
                var sellRate = +(await exchanger.sellRate.call()) / 1000;
                //console.log(sellRate);
                var weiToSendToContract = 40 * tokenMultiplier / sellRate;
                //console.log(weiToSendToContract / tokenMultiplier);
                var sendTx = await runTx(exchanger.refillBalance, [{ from: owner, to: exchanger.address, value: weiToSendToContract }]);
                assertSuccessfulTx(sendTx, "unsuccessful refill of exchanger balance");
    // MINT 20
                var sumToMint = 20 * tokenMultiplier;
                var mint = await runTx(token.mint, [owner, sumToMint]);
                assertSuccessfulTx(mint, "mint tx failed");
                var tokens = await token.balanceOf.call(owner);
                assert.equal(+tokens, sumToMint, "tokens were not minted");

            });

            it("(1) try to sell more than allowance", async function() {
                var token = await LibreCash.deployed(),
                    exchanger = await ComplexExchanger.deployed();
    // APPROVE 10
                var approve = await runTx(token.approve, [exchanger.address, 10 * tokenMultiplier]);
                assertSuccessfulTx(approve, "approve tx failed");
    // SELL 20
                var sellTx = await runTx(exchanger.sellTokens, [owner, 20 * tokenMultiplier]);
    // FAIL ?
                assertUnsuccessfulTx(sellTx, "Selling more tokens than allowed shall fail");            
            });

            it("(2) try to sell more than user has", async function() {
                var token = await LibreCash.deployed(),
                    exchanger = await ComplexExchanger.deployed();
    // USER BALANCE 20
    // APPROVE 20
                var allowanceToSet = 20 * tokenMultiplier;
                var approve = await runTx(token.approve, [exchanger.address, allowanceToSet, {from: owner} ]);
                assertSuccessfulTx(approve, "approve tx failed");
                var allowance = await token.allowance.call(owner, exchanger.address);
                assert.equal(allowanceToSet, allowance, "error setting allowance");
    // SELL 40
                var sellTx = await runTx(exchanger.sellTokens, [owner, 40 * tokenMultiplier]);
    // FAIL ?
                assertUnsuccessfulTx(sellTx, "Selling more tokens than user has shall fail");            
                
            });

            it("(3) try to sell tokens equiv. to less than 1 wei", async function() {
                var token = await LibreCash.deployed(),
                    exchanger = await ComplexExchanger.deployed();
    // USER BALANCE 20
    // APPROVE 20
    // SELL 1 / tokenMultiplier
                var sellTx = await runTx(exchanger.sellTokens, [owner, 1]);
    // FAIL ?
                assertUnsuccessfulTx(sellTx, "Selling minimal count of tokens shall result in 0 eth and revert");            
            });

            it("(4) sell 10 tokens", async function() {
                var token = await LibreCash.deployed(),
                    exchanger = await ComplexExchanger.deployed();
    // EXVHANGER BALANCE ~40
    // USER BALANCE 20
    // APPROVE 20
    // SELL 10
                var sumToSell = 10 * tokenMultiplier;
                var tokensBefore = await token.balanceOf.call(owner);
                var sellTx = await runTx(exchanger.sellTokens, [owner, sumToSell]);
                assertSuccessfulTx(sellTx, "Basic sell - shall be success");   
                var tokensAfter = await token.balanceOf.call(owner);
                assert.equal(+tokensBefore - +tokensAfter, sumToSell, "tokens were not subtracted from balance");        
            });

            it("(5) sell 40 tokens - more than exch. has", async function() {
                var token = await LibreCash.deployed(),
                    exchanger = await ComplexExchanger.deployed();
    // EXVHANGER BALANCE ~30
    // MINT 20
                var sumToMint = 20 * tokenMultiplier;
                var tokensBefore = await token.balanceOf.call(owner);
                var mint = await runTx(token.mint, [owner, sumToMint]);
                assertSuccessfulTx(mint, "mint tx failed");
                var tokensAfter = await token.balanceOf.call(owner);
                assert.equal(+tokensAfter - +tokensBefore, sumToMint, "tokens were not minted");
    // USER BALANCE 30
    // APPROVE 40
                var allowanceToSet = 40 * tokenMultiplier;
                var approve = await runTx(token.approve, [exchanger.address, allowanceToSet, {from: owner} ]);
                assertSuccessfulTx(approve, "approve tx failed");
                var allowance = await token.allowance.call(owner, exchanger.address);
                assert.equal(allowanceToSet, allowance, "error setting allowance");
    // SELL 40
                var sumToSell = 40 * tokenMultiplier;
                var tokensBefore = await token.balanceOf.call(owner);
                var sellTx = await runTx(exchanger.sellTokens, [owner, sumToSell]);
                assertSuccessfulTx(sellTx, "Basic sell - shall be success");   
                var tokensAfter = await token.balanceOf.call(owner);
                assert.isBelow(+tokensBefore - +tokensAfter, sumToSell, "balance change must be below tokens we tried to sell");        
    // EXCH BALANCE ~0
                var balanceExchanger = +web3.eth.getBalance(exchanger.address);
                assert.equal(balanceExchanger, 0, "exchanger balance must be empty");
            });
        });

        context("buy", async function() {
            it("(-) before buy OR sell, init contracts", async function() {
                var token = await LibreCash.deployed(),
                    exchanger = await ComplexExchanger.deployed();
                 
                var exchanger = await ComplexExchanger.deployed(),
                    state = await exchanger.getState.call(),
                    requestPrice = await exchanger.requestPrice.call(),
                    oracleCount = await exchanger.oracleCount.call();
                assert.equal(state.toNumber(), StateENUM.REQUEST_RATES, "the initial state must be REQUEST_RATES");
                assert.equal(requestPrice.toNumber(), 0, "the initial oracle queries price must be 0");
        
                var RR = await runTx(exchanger.requestRates, []);
                assertSuccessfulTx(RR, "requestRates tx failed");
                console.log("[test] successful requestRates()");
                state = await exchanger.getState.call();
                //next line for real oracles
                //assert.equal(state.toNumber(), StateENUM.WAIT_ORACLES, "the state after requestRates must be WAIT_ORACLES");
        
                var crTimeout = Date.now() + 1000 * 60 * 10; // 10 mins
                do {
                    readyOracles = await exchanger.readyOracles.call();
                    waitingOracles = await exchanger.waitingOracles.call();
                    await delay(1000);
                    console.log("delayed");
                } while ((readyOracles.toNumber() != oracleCount.toNumber()) && (Date.now() < crTimeout));
        
                assert.equal(state.toNumber(), StateENUM.CALC_RATES, "the state after gathering oracle data must be CALC_RATES");
                assert.isAtLeast(readyOracles.toNumber(), 2, "ready oracle count must be at least 2");
                var CR = await runTx(exchanger.calcRates, []);
                assertSuccessfulTx(CR, "calcRates tx failed");
                state = await exchanger.getState.call();
                assert.equal(state.toNumber(), StateENUM.PROCESSING_ORDERS, "the state after calcRates must be PROCESSING_ORDERS");
            });
    
            it("(2) buy tokens, no token balance -> revert", async function() {
                var exchanger = await ComplexExchanger.deployed(),
                    token = await LibreCash.deployed();
                var ethToSend = 1,
                    weiToSend = web3.toWei(ethToSend, 'ether');  

                var buyTx = await runTx(exchanger.buyTokens, [owner, { from: owner, value: weiToSend }]);
                assertUnsuccessfulTx(buyTx, "buyTokens tx with zero eth succeeded - bad");
            });

            it("(1) buy 0 tokens -> revert", async function() {
                var exchanger = await ComplexExchanger.deployed(),
                    token = await LibreCash.deployed();
                var sumToMint = 1000 * tokenMultiplier;
                var mint = await runTx(token.mint, [exchanger.address, sumToMint]);
                assertSuccessfulTx(mint, "mint tx failed");
                var tokenBalance = await exchanger.tokenBalance.call();
                assert.equal(tokenBalance.toNumber(), sumToMint, "the token balance after mint is not valid");  

                var ethToSend = 0,
                    weiToSend = 0;

                var buyTx = await runTx(exchanger.buyTokens, [owner, { from: owner, value: weiToSend }]);
                assertUnsuccessfulTx(buyTx, "buyTokens tx with zero eth succeeded - bad");
            });

            it("(3) buy more tokens than exch. has", async function() {
                var exchanger = await ComplexExchanger.deployed(),
                    token = await LibreCash.deployed(),
                    buyFee = await exchanger.buyFee.call(),
                    sellFee = await exchanger.sellFee.call(),
                    tokenBalance = await exchanger.tokenBalance.call(),
                    buyRate = (await exchanger.buyRate.call()) / 1000,
                    exchangerBalance = (await token.balanceOf.call(exchanger.address)) / tokenMultiplier;

                var sumToMint = 1000 * tokenMultiplier;
                //var mint = await runTx(token.mint, [exchanger.address, sumToMint]);
                // already have minted in prev. test
                //assertSuccessfulTx(mint, "mint tx failed");
                var tokenBalance = await exchanger.tokenBalance.call();
                assert.equal(tokenBalance.toNumber(), sumToMint, "the token balance after mint is not valid");  

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

            it("(4) buy 1000 tokens when balance is 1000 tokens", async function() {
                var exchanger = await ComplexExchanger.deployed(),
                    token = await LibreCash.deployed(),
                    buyFee = await exchanger.buyFee.call(),
                    sellFee = await exchanger.sellFee.call(),
                    buyRate = (await exchanger.buyRate.call()) / 1000;
                var accTokensBefore = (await token.balanceOf.call(owner)) / tokenMultiplier;
                var sumToMint = 1000 * tokenMultiplier;
                var mint = await runTx(token.mint, [exchanger.address, sumToMint]);
                assertSuccessfulTx(mint, "mint tx failed");
                var tokenBalance = await exchanger.tokenBalance.call();
                assert.equal(tokenBalance.toNumber(), sumToMint, "the token balance after mint is not valid");  

                var tokensToBuy = 1000,
                    ethToSend = tokensToBuy / buyRate,
                    weiToSend = web3.toWei(ethToSend, 'ether'),
                    balanceBefore = +web3.eth.getBalance(owner);
                var buyTx = await runTx(exchanger.buyTokens, [owner, { from: owner, value: weiToSend }]);
                assertSuccessfulTx(buyTx, "buyTokens tx failed");
                // this is the gas only when exchanger doesn't refund
                var zeroBalance = balanceBefore - +web3.eth.getBalance(owner) - weiToSend -
                    truffleTestGasPrice * buyTx.receipt.gasUsed;
                // if zeroBalance is below 100000, it is insufficient
                assert.isBelow(Math.abs(zeroBalance), 100000, "ether sent doesn't fit the balance changed");

                var accTokensAfter = (await token.balanceOf.call(owner)) / tokenMultiplier;

                console.log(`we sent ${ethToSend} ether`);
                console.log(`rate was ${buyRate}`);
                console.log(`we got ${accTokensAfter - accTokensBefore} tokens`);
                console.log(`shall be ${ethToSend} * ${buyRate} == ${accTokensAfter - accTokensBefore}`);
                assert.equal(ethToSend * buyRate, accTokensAfter - accTokensBefore, "token count doesn't match sent ether multiplied by rate");
            });

            it("(5) buy tokens for 1 eth", async function() {
                var exchanger = await ComplexExchanger.deployed(),
                    token = await LibreCash.deployed(),
                    buyFee = await exchanger.buyFee.call(),
                    sellFee = await exchanger.sellFee.call(),
                    buyRate = (await exchanger.buyRate.call()) / 1000;
                var accTokensBefore = (await token.balanceOf.call(owner)) / tokenMultiplier;

                var sumToMint = 1000 * tokenMultiplier;
                var mint = await runTx(token.mint, [exchanger.address, sumToMint]);
                assertSuccessfulTx(mint, "mint tx failed");
                var tokenBalance = await exchanger.tokenBalance.call();
                assert.equal(tokenBalance.toNumber(), sumToMint, "the token balance after mint is not valid");  

                var ethToSend = 1,
                    weiToSend = web3.toWei(ethToSend, 'ether'),
                    balanceBefore = +web3.eth.getBalance(owner);
                var buyTx = await runTx(exchanger.buyTokens, [owner, { from: owner, value: weiToSend }]);
                assertSuccessfulTx(buyTx, "buyTokens tx failed");
                // this is the gas only when exchanger doesn't refund
                var zeroBalance = balanceBefore - +web3.eth.getBalance(owner) - weiToSend -
                    truffleTestGasPrice * buyTx.receipt.gasUsed;
                // if zeroBalance is below 100000, it is insufficient
                assert.isBelow(Math.abs(zeroBalance), 100000, "ether sent doesn't fit the balance changed");

                var accTokensAfter = (await token.balanceOf.call(owner)) / tokenMultiplier;

                console.log(`we sent ${ethToSend} ether`);
                console.log(`rate was ${buyRate}`);
                console.log(`we got ${accTokensAfter - accTokensBefore} tokens`);
                console.log(`shall be ${ethToSend} * ${buyRate} == ${accTokensAfter - accTokensBefore}`);
                assert.equal(ethToSend * buyRate, accTokensAfter - accTokensBefore, "token count doesn't match sent ether multiplied by rate");
            });
        });
    });

    context("requestRate", function() {
        var jump;

        before("init", async function() {
            let exchanger = await ComplexExchanger.deployed();

            await exchanger.requestRates({from: acc1, value: web3.toWei(5,'ether')});
            jump = Math.max(ORACLE_ACTUAL, ORACLE_TIMEOUT);
            await timeMachine.jump(jump + 1);
            
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
                await exchanger.requestRates({value: oraclesCost + 10000000});
            } catch(e) {
                throw new Error("throw if send > oraclesCost");
            }
            let after = + web3.eth.getBalance(owner);
                weiUsed = getWeiUsedForGas();

            assert.isBelow((before - after) - weiUsed - oraclesCost, 100000, "Don't back left ether!");
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

            assert.isTrue(wBalanceBefore < wBalanceAfter, "Balance wallet don't changed");
            assert.equal(eBalanceAfter, 0, "Withdraw don't all balance");
        });
    });
});