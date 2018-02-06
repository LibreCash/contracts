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

    contract("BuyOrders", async function() {

        before("init", async function() {
            let exchanger = await ComplexExchanger.deployed();

            var oraclePromises = [];
            oracles.forEach(oracle => oraclePromises.push(oracle.deployed()));
            await Promise.all(oraclePromises);
/*
already done in deploy script, why it was here - ?
            oraclePromises = [];
            oracles.forEach(oracle => oraclePromises.push(oracle.setBank(exchanger.address)));*/
        });

        it("get state", async function() {
            let exchanger = await ComplexExchanger.deployed();
            
            let state = parseInt(await exchanger.getState.call());
            console.log(state);
            
            //assert.equal(before + 1, after, "don't add buyOrders, count orders not equal");
            //assert.equal(acc1, result[0], "don't add buyOrders, address not equal");
        });
    });
});