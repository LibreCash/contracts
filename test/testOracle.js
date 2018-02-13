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
 
contract('OracleI', function(accounts) {
    var 
        owner = accounts[0],
        acc1  = accounts[1],
        oracle;

    before("init", async function() {
        oracle = await oracles[0].deployed();
    });

    it('setBank', async function() {
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
        await oracle.setBank(owner);
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

    it("get rate", async function() {
        await oracle.setBank(owner);
        await oracle.updateRate();

        let rate = + await oracle.rate.call();
        assert.equal(rate, 320000, "don't get rate");
    });
});
