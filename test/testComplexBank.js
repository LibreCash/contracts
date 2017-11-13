var ComplexBank = artifacts.require("ComplexBank");

var oraclefiles = [
    "OracleMockLiza",
    "OracleMockSasha"
]

var oracles = [];
oraclefiles.forEach( (filename) => {
    oracles.push(artifacts.require(filename));
});

contract('ComplexBank', function(accounts) {
    var owner = accounts[0];
    var acc1  = accounts[1];
    var acc2  = accounts[2];

    contract("getBuyOrder", function() {
        it("get 0 order", async function() {
            let bank = await ComplexBank.deployed();

            //let result = await bank.getBuyOrder(0);
            //console.log(result);
            return true;
        });
    });

    contract("getOracleCount", function() {
        beforeEach(async function() {
            let bank = await ComplexBank.deployed();
            oracles.forEach( async function(oracle) {
                try {
                    await bank.deleteOracle(oracle.address);
                } catch(e) {}
            });
        });

        it("add Oracle", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();
            //let oracle2 = await OracleMockSasha.deployed();

            let before = parseInt(await bank.getOracleCount.call());
            await bank.addOracle(oracle1.address);
            let after = parseInt(await bank.getOracleCount.call());

            assert.equal(before + 1 , after, "don't added Oracle");
        });

        it("remove oracle", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();
            let oracle2 = await oracles[1].deployed();

            await bank.addOracle(oracle1.address);
            await bank.addOracle(oracle2.address);
            let before = parseInt(await bank.getOracleCount.call());
            await bank.deleteOracle(oracle2.address);
            let after = parseInt(await bank.getOracleCount.call());

            assert.equal(before - 1, after, "don't remove Oracle");
        });
    });

});
