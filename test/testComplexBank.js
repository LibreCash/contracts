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

    contract("BuyOrders", function() {
        it("get 0 order", async function() {
            let bank = await ComplexBank.deployed();

            //let result = await bank.getBuyOrder(0);
            //console.log(result);
            return true;
        });
    });

    contract("Oracles", function() {
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

            let before = parseInt(await bank.getOracleCount.call());
            await bank.addOracle(oracle1.address);
            let after = parseInt(await bank.getOracleCount.call());

            assert.equal(before + 1 , after, "don't added Oracle");
        });

        it("remove Oracle", async function() {
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

        it("dont add not Oracle", async function() {
            let bank = await ComplexBank.deployed();
            let LibreCash = artifacts.require("LibreCash");
            let cash = await LibreCash.deployed();

            try {
                await bank.addOracle(cash.address);
            } catch(e) {
                return true;
            }
            
            throw new Error("Add not Oracles!");
        });

        it("dont add Oracle twice", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            await bank.addOracle(oracle1.address);
            try {
                await bank.addOracle(oracle1.address);
            } catch(e) {
                return true;
            }
            
            throw new Error("Add Oracle twice!");
        });

        it("don't remove havn't Oracle", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();
            
            try {
                await bank.deleteOracle(oracle1.address);
            } catch(e) {
                return true;
            }
            
            throw new Error("remove havn't Oracle!");
        });

        it("After add, enable Oracle", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            
            let before = parseInt(await bank.numEnabledOracles.call());
            await bank.addOracle(oracle1.address);
            let after = parseInt(await bank.numEnabledOracles.call());

            assert.equal(before + 1, after, "don't disable Oracle");
        });

        it("Disable Oracle", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            await bank.addOracle(oracle1.address);
            let before = parseInt(await bank.numEnabledOracles.call());
            await bank.disableOracle(oracle1.address);
            let after = parseInt(await bank.numEnabledOracles.call());

            assert.equal(before - 1, after, "don't disable Oracle");
        });

        it("Don't disable Oracle twice", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            await bank.addOracle(oracle1.address);
            await bank.disableOracle(oracle1.address);
            try {
                await bank.disableOracle(oracle1.address);
            } catch(e) {
                return true;
            }
            
            throw new Error("Disable Oracle twice!");
        });

        it("Don't disable haven't Oracle", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            try {
                await bank.disableOracle(oracle1.address);
            } catch(e) {
                return true;
            }
            
            throw new Error("Disable haven't Oracle!");
        });

        it("Don't disable Oracle, when disabled", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            await bank.addOracle(oracle1.address);
            await bank.disableOracle(oracle1.address);
            try {
                await bank.disableOracle(oracle1.address);
            } catch(e) {
                return true;
            }
            
            throw new Error("Disable Oracle, when disabled!");
        });

        it("Enable oracle", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            await bank.addOracle(oracle1.address);
            await bank.disableOracle(oracle1.address);
            let before = parseInt(await bank.numEnabledOracles.call());
            await bank.enableOracle(oracle1.address);
            let after = parseInt(await bank.numEnabledOracles.call());

            assert.equal(before + 1, after, "don't enable Oracle");
        });

        it("Don't enable haven't Oracle", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            try {
                await bank.enableOracle(oracle1.address);
            } catch(e) {
                return true;
            }
            
            throw new Error("Enable haven't Oracle");
        });

        it("Don't enable Oracle, when enabled", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            await bank.addOracle(oracle1.address);
            try {
                await bank.enableOracle(oracle1.address);
            } catch(e) {
                return true;
            }
            
            throw new Error("Enable Oracle, when enabled");
        });
    });

});
