var OracleMockTest = artifacts.require("OracleMockTest");

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
        
        let rate = await oracle.rate.call();
        assert.equal(rate, 100, "don't get rate");
    });
});
