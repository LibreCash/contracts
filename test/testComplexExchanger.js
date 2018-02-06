var ComplexExchanger = artifacts.require("ComplexExchanger");

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

contract('ComplexExchanger', function(accounts) {
    var owner = accounts[0];
    var acc1  = accounts[1];
    var acc2  = accounts[2];
    var oracle1 = oracles[3];

    contract("getState", async function() {

        before("init", async function() {
            let exchanger = await ComplexExchanger.deployed();

            var oraclePromises = [];
            oracles.forEach(oracle => oraclePromises.push(oracle.deployed()));
            await Promise.all(oraclePromises);
        });
        
        it.only("get state", async function() {
            var exchanger = await ComplexExchanger.deployed();
            var state = await exchanger.getState.call();
            assert.equal(state.toNumber(), 5, "the state must be 5"); // 4 actually
        });
    });
});