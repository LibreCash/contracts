var OraclePoloniex = artifacts.require("./OraclePoloniex.sol");

contract('OraclePoloniex', function() {
    it("sets-gets rate", function() {

      OraclePoloniex.deployed().then(function(oracle){
          oracle.setRate(100);
          var rate = oracle.getRate.call();
          //Uncaught Error: Invalid number of arguments to Solidity function
          // with "101" argument shall not pass but passong
          assert.equal(rate, 101, "rate not set");
      });
    });
});
