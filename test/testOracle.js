var OracleMockTest = artifacts.require("OracleMockTest");
var CompleBank = artifacts.require("ComplexBank");
var OwnOracle = artifacts.require("OwnOracle");

function sleep(miliseconds) {
    var currentTime = new Date().getTime();
 
    while (currentTime + miliseconds >= new Date().getTime()) {
    }
 }
 
contract('OracleI', async function(accounts) {
    var owner = accounts[0];
    var acc1  = accounts[1];

    it('setBank', async function() {
        let oracle = await OracleMockTest.deployed();

        try {
            await oracle.setBank(owner);
        } catch(e) {
            throw new Error("Owner dont set Bank!!");
        }

        try {
            await oracle.setBank(owner, {from:acc1});
        } catch(e) {
            return true;
        }
        throw new Error("Not Owner set Bank!!");
    });

    it('updateRate', async function() {
        let oracle = await OracleMockTest.deployed();

        try {
            await oracle.updateRate();
        } catch(e) {
            throw new Error("Owner dont update rate!!");
        }

        try {
            await oracle.updateRate({from:acc1});
        } catch(e) {
            return true;
        }
        throw new Error("Not Bank update Rate!!");
    });

    it('clearState', async function() {
        let oracle = await OracleMockTest.deployed();

        await oracle.setBank(owner);
        try {
            await oracle.clearState({from:owner});
        } catch(e) {
            throw new Error("Owner dont clearState!!");
        }

        try {
            console.log(await oracle.clearState({from:acc1}));
        } catch(e) {
            return true;
        }
        throw new Error("Not Bank clearState!!");
    });

    it("waitQuery",async function() {
        let oracle = await OracleMockTest.deployed();

        await oracle.setBank(owner);
        await oracle.clearState();
        let wait = await oracle.waitQuery.call();
        assert.isFalse(wait, "wait dont clear");
    });

    it("get rate", async function() {
        let oracle = await OracleMockTest.deployed();
        
        let rate = parseInt(await oracle.rate.call());
        assert.equal(rate, 1000, "don't get rate");
    });

    it("requestUpdateRate", async function() {
        let bank = await CompleBank.deployed();

        let oracle = await bank.firstOracle.call();
        let before = parseInt(web3.eth.getBalance(oracle));

        try {
            console.log("contractState", parseInt(await bank.contractState.call()));
            console.log("getOracleDeficit", parseInt(await bank.getOracleDeficit.call()));
            await bank.requestUpdateRates({value: web3.toWei(1,'ether')});
        } catch(e) {
            throw new Error("requestUpdateRate don't work if send ether!!");
        }

        try {
            await bank.requestUpdateRates();
        } catch(e) {
            let after = parseInt(web3.eth.getBalance(oracle));
            assert.isTrue(before < after, "Oracle balance don't change");

            return true;
        }

        throw new Error("requestUpdateRate work if don't send ether!!");
    });

    it("OwnOracle", async function() {
        let oracle = await OwnOracle.deployed();

        let before = parseInt(await oracle.rate.call());
        await oracle.setUpdaterAddress(acc1);
        try {
            await oracle.__callback((before/1000 + 12).toString(),{from: acc1});
        } catch(e) {
            throw new Error("__callback don't work if call updaterAddress!!");
        }

        try {
            await oracle.__callback("10");
        } catch(e) {
            let after = parseInt(await oracle.rate.call());

            assert.equal(before + 12, after, "don't set rate");
            return true;
        }

        throw new Error("__callback work if call not updaterAddress!!");
    });
});
