//var utils = require("./utils.js");
//var OracleBitfinex = artifacts.require("./OracleBitfinex.sol");
//var OracleBitstamp = artifacts.require("./OracleBitstamp.sol");
//var OracleGDAX = artifacts.require("./OracleGDAX.sol");

Date.prototype.timeNow = function () {
    return ((this.getHours() < 10)?"0":"") + this.getHours() +":"+ ((this.getMinutes() < 10)?"0":"") + this.getMinutes() +":"+ ((this.getSeconds() < 10)?"0":"") + this.getSeconds();
}

function Log(anything) {
    console.log((new Date()).timeNow() + ' [test] ' + anything);
}

function showTransactionEvents(txName, logs) {
    if (logs != null) {
        Log(txName + ' events:');
        logs.forEach(function(element) {
            console.log(element.args);
        }, this);
    }
}

function getBalance() {
    return web3.eth.getBalance(web3.eth.accounts[0]).toNumber()*10**-18;
}

var LibreCash = artifacts.require("./LibreCash.sol");
var SimplexBank = artifacts.require("./SimplexBank.sol");
var OracleBitfinex = artifacts.require("./OracleBitfinex.sol");

var oracle;
var oracleDeployed;
var tokenDeployed;
var bankDeployed;

contract('LibreCash', function() {
    it("LibreCash", async function() {
        tokenDeployed = await LibreCash.deployed();
    });
});
contract('OracleBitfinex', function() {
    it("OracleBitfinex", async function() {
        oracle = await OracleBitfinex.new();
        //oracleDeployed = await OracleBitfinex.deployed();
    });
});
var bankDeployed;
contract('SimplexBank', function() {
    it("gets oracleRating as 5000", async function() {
        Log('await SimplexBank.new() before');
        var bank = await SimplexBank.new();
        bankDeployed = await SimplexBank.deployed();
//        oracleDeployed = await OracleBitfinex.deployed();
        var oracleAddress = oracle.address;
        var tokenAddress = tokenDeployed.address;
        await bankDeployed.setToken(tokenAddress);
        await bankDeployed.setOracle(oracleAddress);
        Log('oracle addr: ' + (await bankDeployed.getOracle.call()).valueOf());
        Log('token addr: ' + (await bankDeployed.getToken.call()).valueOf());
        var testAllowed = false;
        var timestampTimeout = (new Date()).timeNow();
        Log('waiting for beginning...');
        do {
            testAllowed = (await bankDeployed.areTestsAllowed()).valueOf();
            timestampInner = (new Date()).getTime();
            while ((new Date()).getTime() - timestampInner < 500) {}
            process.stdout.write('|');
        } while ((!testAllowed) || ((new Date()).getTime() - timestampTimeout < 60000));
        console.log();

        var oracleAddress = (await bankDeployed.getOracle.call()).valueOf();
        
        let res = (await bankDeployed.getOracleRating.call()).valueOf();
        Log('oracleRating: ' + res);    
        assert.equal(res, 5000, "rating not set or wrong");
    }); // it
    it('updates rate and gets it', async function() {
        var rate = 0;
        Log('await updateRate before');
        var ethBalance = getBalance();
        var updateRateTX = await bankDeployed.updateRate();
        console.log(updateRateTX.receipt.gasUsed);
        Log('await updateRate after');
        showTransactionEvents('updateRate', updateRateTX.logs);
        var hasReceivedRate = false;
        var timestampTimeout = (new Date()).getTime();
        Log('waiting for callback...');
        do {
            hasReceivedRate = (await bankDeployed.hasReceivedRate.call()).valueOf();
            timestampInner = (new Date()).getTime();
            while ((new Date()).getTime() - timestampInner < 500) {}
            rate = (await bankDeployed.getRate.call()).valueOf();
            process.stdout.write('|');
        } while ((!hasReceivedRate) || ((new Date()).getTime() - timestampTimeout < 120000));
        console.log(); Log('rate = ' + rate);
        Log('callback time: ' + ((new Date()).getTime() - timestampTimeout).toString());
        Log('callback+updateRate eth consumption: ' + (getBalance() - ethBalance).toString());
    }); // it
});
