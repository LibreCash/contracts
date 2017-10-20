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
var simplexBankABI = "[{\"constant\":true,\"inputs\":[],\"name\":\"getRate\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\"}],\"name\":\"sellTokens\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"totalTokenCount\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_address\",\"type\":\"address\"}],\"name\":\"setOracle\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_beneficiar\",\"type\":\"address\"}],\"name\":\"withdrawCrypto\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"getOracleRating\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_beneficiar\",\"type\":\"address\"}],\"name\":\"buyTokens\",\"outputs\":[],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"donate\",\"outputs\":[],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_address\",\"type\":\"address\"},{\"name\":\"_rate\",\"type\":\"uint256\"},{\"name\":\"_time\",\"type\":\"uint256\"}],\"name\":\"oraclesCallback\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"name\":\"_tokenContract\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"fallback\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"name\":\"anything\",\"type\":\"string\"}],\"name\":\"Log\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"name\":\"addr\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"anything\",\"type\":\"string\"}],\"name\":\"Log\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"name\":\"addr\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"value1\",\"type\":\"uint256\"},{\"indexed\":false,\"name\":\"value2\",\"type\":\"uint256\"}],\"name\":\"Log\",\"type\":\"event\"}]";

Date.prototype.timeNow = function () {
    return ((this.getHours() < 10)?"0":"") + this.getHours() +":"+ ((this.getMinutes() < 10)?"0":"") + this.getMinutes() +":"+ ((this.getSeconds() < 10)?"0":"") + this.getSeconds();
}

function Log(anything) {
    console.log((new Date()).timeNow() + ' [test] ' + anything);
}


var SimplexBank = artifacts.require("./SimplexBank.sol");
var OracleBitfinex = artifacts.require("./OracleBitfinex.sol");
var oracle;
var oracleDeployed;
contract('OracleBitfinex', function() {
    it('creates oracle', async function() {
        Log('await OracleBitfinex.new() before');
        oracle = await OracleBitfinex.new();
        Log('await OracleBitfinex.new() after');
    });
});
var bankDeployed;
contract('SimplexBank', function() {
    it("gets oracleRating as 5000", async function() {
        Log('await SimplexBank.new() before');
        var bank = await SimplexBank.new();
        //var bank = await web3.eth.contract(simplexBankABI, '0x0e1a39c2c19a81a33b784fa1d74a7e4b31a502dc');
        bankDeployed = await SimplexBank.deployed();
        Log('await SimplexBank.deployed() after');
        
        Log('addr: ' + bankDeployed.address); 

        let res = (await bankDeployed.getOracleRating.call()).valueOf();
        Log('oracleRating: ' + res);    
        assert.equal(res, 5000, "rating not set or wrong");
    });
});
contract('OracleBitfinex', function() {
    it("calls updateRate", async function() {
        var rate = 0;
        //oracleDeployed = await OracleBitfinex.deployed();
        Log('await OracleBitfinex.new() after');
        Log('await updateRate before');
        var updateRate = await oracle.updateRate();
        Log('await updateRate after');
        updateRate.logs.forEach(function(element) {
            console.log(element.args);
        }, this);
        // todo: почему в конструкторе не ставится
        await oracle.setBank(bankDeployed.address);
        var oracleBank = (await oracle.getBank.call()).valueOf();
        Log("oracle bank: " + oracleBank);
        var hasReceivedRate = false;
        var timestampTimeout = (new Date()).timeNow();
        Log('waiting for callback...');
        while ((!hasReceivedRate) || ((new Date()).getTime() - timestampTimeout < 120000)) {
            Log('still waiting');
            hasReceivedRate = (await oracle.hasReceivedRate.call()).valueOf();
            timestampInner = (new Date()).getTime();
            while ((new Date()).getTime() - timestampInner < 5000) {}
            rate = (await bankDeployed.getRate.call()).valueOf();
            console.log(rate);
        }
        
    });
});
