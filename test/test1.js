var OracleBitfinex = artifacts.require("./OracleBitfinex.sol");

contract('OracleBitfinex', function() {
    it("sets-gets rate", function() {

      OracleBitfinex.deployed().then(function(oracle){
          oracle.setRate(100);
          var rate = oracle.getRate();
          //Uncaught Error: Invalid number of arguments to Solidity function
          assert.equal(rate, 100, "rate not set");
      });
    });
});
