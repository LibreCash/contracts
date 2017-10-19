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

// DUMMY TEST
var SimplexBank = artifacts.require("./SimplexBank.sol");
contract('SimplexBank', function() {
    it("sets-gets dummy", async function() {
        var bank = await SimplexBank.deployed();
        await bank.setDummy(2128506);
        let res = (await bank.getDummy.call()).valueOf();
        console.log(res);    
            // этот тест как бы вообще не должен проходить, а он проходит
            // скорее всего этот then() просто не работает
            assert.equal(res, 100, "dummy not set or wrong");
    });
});