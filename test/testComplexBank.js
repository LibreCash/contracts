var ComplexBank = artifacts.require("ComplexBank");
var LibreCash = artifacts.require("LibreCash");

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

contract('ComplexBank', function(accounts) {
    var owner = accounts[0];
    var acc1  = accounts[1];
    var acc2  = accounts[2];
    var oracle1 = oracles[3];

    contract("BuyOrders", async function() {

        before("init", async function() {
            let bank = await ComplexBank.deployed();

            oracles.forEach( async function(oracle) {
                await oracle.deployed();
                try {
                    await bank.deleteOracle(oracle.address);
                } catch(e) {}
            });

            let oracleTest = await oracle1.deployed();
            await oracleTest.setBank(bank.address);
            await bank.addOracle(oracleTest.address);

            await bank.requestUpdateRates();
            await bank.calcRates();
            //console.log(await bank.cryptoFiatRateBuy.call());
            //console.log(await bank.cryptoFiatRateSell.call());
        });

        beforeEach("clear orders", async function() {
            let bank = await ComplexBank.deployed();
            
            try {
                await bank.unpause();
            } catch(e) {}
            try {
                await bank.processBuyQueue(0);
            } catch(e) {
                //console.log(e);
            }
        });

        it("add buyOrders", async function() {
            let bank = await ComplexBank.deployed();
            
            let before = parseInt(await bank.getBuyOrdersCount.call());
            await bank.sendTransaction({from: acc1, value: web3.toWei(5,'ether')});
            let after = parseInt(await bank.getBuyOrdersCount.call());
            let result = await bank.getBuyOrder(before);
            
            assert.equal(before + 1, after, "don't add buyOrders, count orders not equal");
            assert.equal(acc1, result[0], "don't add buyOrders, address not equal");
        });

        it("add buyOrders with rate", async function() {
            let bank = await ComplexBank.deployed();

            let before = parseInt(await bank.getBuyOrdersCount.call());
            await bank.createBuyOrder(acc1, 10, {from: owner, value: web3.toWei(6,'ether')});
            let after = parseInt(await bank.getBuyOrdersCount.call());
            let result = await bank.getBuyOrder(before);
            
            assert.equal(before + 1, after, "don't add buyOrders with rate, count orders not equal");
            assert.isTrue( (result[0] == owner) && (result[1] == acc1) && 
                            (result[2] == web3.toWei(6,'ether')) && (result[4] == 10), "don't add buyOrders with rate, dont correct order")
        });

        it("pause send to buyOrder", async function(){
            let bank = await ComplexBank.deployed();

            await bank.pause();
            let before = parseInt(web3.eth.getBalance(owner));
            try {
                await bank.sendTransaction({from: acc1, value: web3.toWei(7,'ether')});
            } catch(e) {
                let after = parseInt(web3.eth.getBalance(owner));
                return assert.equal(before, after, "don't pause send to buyOrder, balances before and after not equal");
            }
            
            throw new Error("Dont pause send to buyOrder!");
        });

        it("pause createBuyOrder", async function(){
            after(async function() {
                let bank = await ComplexBank.deployed();
                
                try {
                    await bank.unpause();
                } catch(e) {}
            });
            let bank = await ComplexBank.deployed();

            await bank.pause();
            let before = web3.eth.getBalance(owner);
            try {
                await bank.createBuyOrder(acc1, 10, {from: owner, value: web3.toWei(3,'ether')}); 
            } catch(e) {
                let after = web3.eth.getBalance(owner);
                let price = web3.eth.gasPrice * web3.eth.gasPrice.e;
                let etherUsed = web3.eth.getBlock("latest").gasLimit * price;

                return assert.isTrue(parseInt(before - after) <= etherUsed, "don't pause createBuyOrder, balances before and after not equal");
            }
            
            throw new Error("Dont pause createBuyOrder!");
        });

        it("mint cash", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();
            
            let before = parseInt(await cash.balanceOf(acc1));
            let amount = parseInt(web3.toWei(3,'ether'));
            await bank.sendTransaction({from: acc1, value: amount});
            await bank.processBuyQueue(0);
            let after = parseInt(await cash.balanceOf(acc1));

            assert.equal(before + amount, after, "Don't mint cash");
        });

        it("mint with rate", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            let tokenBefore = parseInt(await cash.balanceOf(owner));
            let before = parseInt(web3.eth.getBalance(owner));
            await bank.createBuyOrder(acc1, 10, {from: owner, value: web3.toWei(3,'ether')});
            await bank.processBuyQueue(0);
            let after = parseInt(web3.eth.getBalance(owner));

            let price = web3.eth.gasPrice * web3.eth.gasPrice.e;
            let etherLimit = web3.eth.getBlock("latest").gasLimit * price;

            assert.isTrue((before - after) <= etherLimit, "Don't mint cash with rate");
        });

    });
    
    contract("Sell Orders", function() {

        before("init", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            oracles.forEach( async function(oracle) {
                await oracle.deployed();
                try {
                    await bank.deleteOracle(oracle.address);
                } catch(e) {}
            });

            let oracleTest = await oracles[3].deployed();
            await oracleTest.setBank(bank.address);
            await bank.addOracle(oracleTest.address);

            await bank.requestUpdateRates();
            await bank.calcRates();
            //console.log(await bank.cryptoFiatRateBuy.call());
            //console.log(await bank.cryptoFiatRateSell.call());
            
            await bank.sendTransaction({from: owner, value: web3.toWei(7,'ether')});
            await bank.processBuyQueue(0);
        });

        beforeEach("clear orders", async function() {
            let bank = await ComplexBank.deployed();

            try {
                await bank.unpause();
            } catch(e) {}

            try {
                //console.log(
                    await bank.processSellQueue(0);//);
            } catch(e) {
                //console.log(e);
            }
        });

        it("add sellOrders", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            let before = parseInt(await bank.getSellOrdersCount.call());
            let tokenBefore = parseInt(await cash.balanceOf(owner));

            await bank.createSellOrder(owner, 12, 0);

            let after = parseInt(await bank.getSellOrdersCount.call());
            let tokenAfter = parseInt(await cash.balanceOf(owner));
            let result = await bank.getSellOrder(before);

            assert.equal(before + 1, after,"don't add sellorders");
            assert.equal(result[1], owner,"don't right address in sell orders");
            assert.equal(result[2], 12, "don't right amount sell tokens in sellorders");
            assert.equal(result[4], 0, "don't right ratelimit in sellorders");
            assert.equal(tokenAfter + 12, tokenBefore, "don't burn tokens");
        });

        it("add sellOrders when paused", async function() {
            let bank = await ComplexBank.deployed();

            await bank.pause();
            let before = parseInt(await bank.getSellOrdersCount.call());
            try {
                await bank.createSellOrder(owner, 12, 0);
            } catch(e) {
                let after = parseInt(await bank.getSellOrdersCount.call());
                return assert.equal(before, after,"Add in sellorders when paused");
            }
            
            throw new Error("Dont pause createSellOrder!");
        });

        it("add sellOrder when have token < then in sellorder", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            let balance = parseInt(cash.balanceOf(acc1));
            try {
                await bank.createSellOrder(owner, balance + 10, 0,{from: acc1});
            } catch(e) {
                return true;
            }
            
            throw new Error("Dont check balance createSellOrder!");
        });

        it("burn cash", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();
            
            let tokenBefore = parseInt(await cash.balanceOf(owner));
            let etherBefore = parseInt(web3.eth.getBalance(acc1));

            await bank.createSellOrder(acc1, tokenBefore/2, 0);
            await bank.processSellQueue(0);

            let tokenAfter = parseInt(await cash.balanceOf(owner));
            let etherAfter = parseInt(web3.eth.getBalance(acc1));

            assert.equal(tokenAfter , tokenBefore/2, "Don't burn token");
            assert.equal(tokenBefore/2, etherAfter - etherBefore, "Don't send ether!");
        });

        it("burn with ratelimit", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            let before = parseInt(await cash.balanceOf(owner));

            await bank.createSellOrder(acc1, before/2, 110);
            await bank.processSellQueue(0);

            let after = parseInt(web3.eth.getBalance(owner));

            let price = web3.eth.gasPrice * web3.eth.gasPrice.e;
            let etherLimit = web3.eth.getBlock("latest").gasLimit * price;

            assert.isTrue((before - after) <= etherLimit, "Don't burn cash with ratelimit");
        });

    });

    contract("Oracles", function() {
        beforeEach(async function() {
            let bank = await ComplexBank.deployed();
            oracles.forEach( async function(oracle) {
                oracle.deployed();
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

            let oracleData = await bank.oracles.call(oracle1.address);
            let nameOracle = await oracle1.oracleName.call();

            assert.equal(before + 1 , after, "don't added Oracle");
            assert.equal(oracleData[0], nameOracle, "don't set name for added oracle");
            assert.equal(oracleData[2], true, "don't enable added Oracle");
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
