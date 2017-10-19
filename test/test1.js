//var utils = require("./utils.js");
//var OracleBitfinex = artifacts.require("./OracleBitfinex.sol");
//var OracleBitstamp = artifacts.require("./OracleBitstamp.sol");
//var OracleGDAX = artifacts.require("./OracleGDAX.sol");
var LibreBank = artifacts.require("./LibreBank.sol");

contract('LibreBank', function() {
    it("sets-gets MinTransactionAmount", function() {
        //var bank = LibreBank.deployed();
        LibreBank.deployed().then(function(bank){
            bank.setMinTransactionAmount(100);
            let res = bank.getMinTransactionAmount();
            
            assert.equal(res, 105, "MinTransactionAmount not set or wrong");
 /*         assert.equal(100, 200, '100!=200');
          assert.notEqual(100, 200, '100==200');*/
      });
    });
});
