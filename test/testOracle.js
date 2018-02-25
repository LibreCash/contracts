const assertTx = new (require('./helpers/assertTx'))();
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
        await assertTx.success(oracle.setBank(owner),"Owner dont set Bank!!");
        await assertTx.fail(oracle.setBank(owner, {from:acc1}),"Not Owner set Bank!!");
    });

    it('updateRate', async function() {
        await oracle.setBank(owner);
        await assertTx.success(oracle.updateRate(),"Owner dont update rate!!");
        await assertTx.fail(oracle.updateRate({from:acc1}), "Not Bank update Rate!!");
    });

    it("get rate", async function() {
        await oracle.setBank(owner);
        await oracle.updateRate();

        let rate = + await oracle.rate.call();
        assert.equal(rate, 320000, "don't get rate");
    });
});
