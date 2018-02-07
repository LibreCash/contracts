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

contract('ComplexExchanger', function(accounts) {
    var owner = accounts[0];
    var acc1  = accounts[1];
    var acc2  = accounts[2];
    var oracle1 = oracles[3];

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
        before("buy tokens", async function() {
            var token = await LibreCash.deployed(),
                exchanger = await ComplexExchanger.deployed();
            var sumToMint = 100000 * Math.pow(10, 18);
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
    
        it.only("buy tokens", async function() {
            var exchanger = await ComplexExchanger.deployed(),
                token = await LibreCash.deployed(),
                buyFee = await exchanger.buyFee.call(),
                sellFee = await exchanger.sellFee.call();
            var ethToSend = 5,
                weiToSend = web3.toWei(ethToSend, 'ether'),
                balanceBefore = web3.eth.getBalance(acc1).toNumber();
            var buyTx = await exchanger.buyTokens(acc1, { from: acc1, value: weiToSend });
            assert.equal(buyTx.receipt.status, 1, "buyTokens tx failed");
            var factGasInEth = web3.fromWei(balanceBefore - web3.eth.getBalance(acc1).toNumber() - weiToSend, 'ether');
            assert.isAbove(factGasInEth, 0, "used gas must be positive");
            assert.isBelow(factGasInEth, 0.1, "seems too much gas used");
            
            var buyRate = (await exchanger.buyRate.call()) / 1000,
                boughtTokens = (await token.balanceOf.call(acc1)) / Math.pow(10, 18);

            console.log(`we sent ${ethToSend} ether`);
            console.log(`rate was ${buyRate}`);
            console.log(`we got ${boughtTokens} tokens`);
            console.log(`shall be ${ethToSend} * ${buyRate} == ${boughtTokens}`);
            assert.equal(ethToSend * buyRate, boughtTokens, "token count doesn't match sent ether multiplied by rate");
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

        before("check state", async function() {
            let exchanger = await ComplexExchanger.deployed();
            let state = + await exchanger.getState.call();
            assert.equal(state, StateENUM.LOCKED,"Don't correct state!!");
        });

        it("Don't withdraw if not wallet", async function() {
            let exchanger = await ComplexExchanger.deployed();

            try {
                await exchanger.withdrawReserve({from: acc1});
            } catch(e) {
                return true;
            }

            throw new Error("Not wallet withdraw reserve!!");
        });
    });
});