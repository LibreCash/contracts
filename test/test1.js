//var utils = require("./utils.js");
//var OracleBitfinex = artifacts.require("./OracleBitfinex.sol");
//var OracleBitstamp = artifacts.require("./OracleBitstamp.sol");
//var OracleGDAX = artifacts.require("./OracleGDAX.sol");
/*var LibreBank = artifacts.require("./LibreBank.sol");

contract('LibreBank', function() {
    it("sets-gets MinTransactionAmount", function() {
        //var bank = LibreBank.deployed();
        LibreBank.deployed().then(function(bank){
            bank.setMinTransactionAmount(100);
            let res = bank.getMinTransactionAmount();
            
            assert.equal(res, 105, "MinTransactionAmount not set or wrong");
      });
    });
});
*/
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


var LibreCoin = artifacts.require("./LibreCoin.sol");
var SimplexBank = artifacts.require("./SimplexBank.sol");
var OracleBitfinex = artifacts.require("./OracleBitfinex.sol");

var oracle;
var oracleDeployed;
var tokenDeployed;
var bankDeployed;

var bankAddress = SimplexBank.address;
var bankABI = SimplexBank._json.abi;
//var bank = await web3.eth.contract(simplexBankABI, '0x0e1a39c2c19a81a33b784fa1d74a7e4b31a502dc');
contract('LibreCoin', function() {
    it("LibreCoin", async function() {
        tokenDeployed = await LibreCoin.deployed();
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
        Log('oracle bank addr: ' + (await bankDeployed.getOracleBankAddress.call()).valueOf());
        Log('token bank addr: ' + (await bankDeployed.getTokenBankAddress.call()).valueOf());
//        Log('bankDeployed=... after');
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
    //    await bankDeployed.setToken(tokenDeployed.address);

//    Log('cmp to token addr: ' + tokenDeployed.address);
    //    await bankDeployed.setOracle(oracle.address);
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
            //console.log(rate);
        } while ((!hasReceivedRate) || ((new Date()).getTime() - timestampTimeout < 120000));
        console.log(); Log('rate = ' + rate);
        Log('callback time: ' + ((new Date()).getTime() - timestampTimeout).toString());
        Log('callback+updateRate eth consumption: ' + (getBalance() - ethBalance).toString());
    }); // it
});
