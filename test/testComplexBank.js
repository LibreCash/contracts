var ComplexBank = artifacts.require("ComplexBank");
var LibreCash = artifacts.require("LibreCash");

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

    contract("BuyOrders", async function() {

        before('init', async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();
            await bank.attachToken(cash.address);
            await bank.addOracle(oracles[0].address);
            await bank.addOracle(oracles[1].address);
            //console.log(parseInt(await bank.numEnabledOracles()));
            //console.log(parseInt(await bank.numWaitingOracles()));
            //console.log(await bank.getOracleRate(oracles[0].address));

            //await bank.requestUpdateRates();
            //console.log(await bank.numReadyOracles());
            //await bank.calcRates();
        });

        beforeEach("clear orders", async function() {
            let bank = await ComplexBank.deployed();
            
            try {
                await bank.unpause();
            } catch(e) {}
            try {
                await bank.processBuyQueue(0);
            } catch(e) {
                console.log(e);
            }
        });

        it("add buyOrders", async function() {
            let bank = await ComplexBank.deployed();
            
            let before = parseInt(await bank.getBuyOrdersCount.call());
            await bank.sendTransaction({from: acc1, value: 5});
            let after = parseInt(await bank.getBuyOrdersCount.call());
            let result = await bank.getBuyOrder(before);
            
            assert.equal(before + 1, after, "don't add buyOrders, count orders not equal");
            assert.equal(acc1, result[0], "don't add buyOrders, address not equal");
        });

        it("add buyOrders with rate", async function() {
            let bank = await ComplexBank.deployed();

            let before = parseInt(await bank.getBuyOrdersCount.call());
            await bank.createBuyOrder(acc1, 10, {from: owner, value: 6});
            let after = parseInt(await bank.getBuyOrdersCount.call());
            let result = await bank.getBuyOrder(before);
            
            assert.equal(before + 1, after, "don't add buyOrders with rate, count orders not equal");
            assert.isTrue( (result[0] == owner) && (result[1] == acc1) && 
                            (result[2] == 6) && (result[4] == 10), "don't add buyOrders with rate, dont correct order")
        });

        it("pause send to buyOrder", async function(){
            let bank = await ComplexBank.deployed();

            await bank.pause();
            let before = parseInt(web3.eth.getBalance(owner));
            try {
                await bank.sendTransaction({from: acc1, value: 7});
            } catch(e) {
                let after = parseInt(web3.eth.getBalance(owner));
                return assert.equal(before, after, "don't pause send to buyOrder, balances before and after not equal");
            }
            
            throw new Error("Dont pause send to buyOrder!");
        });

        it("pause createBuyOrder", async function(){
            let bank = await ComplexBank.deployed();

            await bank.pause();
            let before = parseInt(web3.eth.getBalance(owner));
            try {
                await bank.createBuyOrder(acc1, 10, {from: owner, value: 6});
            } catch(e) {
                let after = parseInt(web3.eth.getBalance(owner));
                return assert.equal(before, after, "don't pause createBuyOrder, balances before and after not equal");
            }
            
            throw new Error("Dont pause createBuyOrder!");
        });
    });
    
    contract("Sell Orders", function() {

        beforeEach("clear orders", async function() {
            let bank = await ComplexBank.deployed();

            try {
                //console.log(
                    await bank.processSellQueue(0);//);
            } catch(e) {}
        });

        it("add sellOrders", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();
            
            console.log(await cash.balanceOf(owner));
            //let before = parseInt(await bank.getSellOrdersCount.call());
            //await bank.send(5);
            //let after = parseInt(await bank.getSellOrdersCount.call());
            //let result = await bank.getSellOrder(before);
            
            //assert.isTrue((before + 1 == after) && (owner == result[0]), "don't add SellOrders");
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

        it("Don't add Oracle if not owner", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            try {
                await bank.addOracle(oracle1.address,{from: acc1});
            } catch(e) {
                return true;
            }
            
            throw new Error("Add Oracle if not owner!");
        });

        it("Don't remove Oracle if not owner", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            await bank.addOracle(oracle1.address);
            try {
                await bank.deleteOracle(oracle1.address,{from: acc1});
            } catch(e) {
                return true;
            }
            
            throw new Error("Remove Oracle if not owner!");
        });

        it("Don't enable Oracle if not owner", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            await bank.addOracle(oracle1.address);
            await bank.disableOracle(oracle1.address);
            try {
                await bank.enableOracle(oracle1.address,{from: acc1});
            } catch(e) {
                return true;
            }
            
            throw new Error("Enable Oracle if not owner!");
        });

        it("Don't disable Oracle if not owner", async function() {
            let bank = await ComplexBank.deployed();
            let oracle1 = await oracles[0].deployed();

            await bank.addOracle(oracle1.address);
            try {
                await bank.disableOracle(oracle1.address,{from: acc1});
            } catch(e) {
                return true;
            }
            
            throw new Error("Disable Oracle if not owner!");
        });
    });

});
