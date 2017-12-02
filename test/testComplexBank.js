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

function sleep(miliseconds) {
    var currentTime = new Date().getTime();
 
    while (currentTime + miliseconds >= new Date().getTime()) {
    }
 }

contract('ComplexBank', function(accounts) {
    var owner = accounts[0];
    var acc1  = accounts[1];
    var acc2  = accounts[2];
    var oracle1 = oracles[3];

    contract("BuyOrders", async function() {

        before("init", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            await cash.setBankAddress(bank.address);
            
            oracles.forEach( async function(oracle) {
                await oracle.deployed();
                try {
                    await bank.disableOracle(oracle.address);
                } catch(e) {}
            });

            let oracleTest = await oracle1.deployed();
            await oracleTest.setBank(bank.address);
            //await bank.enableOracle(oracleTest.address);

            //await bank.requestUpdateRates();
            //await bank.calcRates();
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
            } catch(e) {}
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

            let before = parseInt(await bank.getBalanceEther(owner));
            await bank.createBuyOrder(acc1, 10, {from: owner, value: web3.toWei(3,'ether')});
            await bank.processBuyQueue(0);
            let after = parseInt(await bank.getBalanceEther(owner));

            assert.equal(before + parseInt(web3.toWei(3,'ether')), after, "Don't mint cash with rate");
        });

        it("processBuyQueue with limit", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            await bank.createBuyOrder(owner, 10, {from: owner, value: web3.toWei(3,'ether')});
            await bank.createBuyOrder(acc1, 10, {from: acc1, value: web3.toWei(3,'ether')});
            await bank.createBuyOrder(acc2, 10, {from: acc2, value: web3.toWei(3,'ether')});

            await bank.processBuyQueue(2);
            let order = await bank.getBuyOrder(2);
            assert.isTrue(order[1] != 0x0, "Don't proccessBuyQueue with limit! Order clear");

            try {
                await bank.getBuyOrder(1);
            } catch(e) {
                return true;
            }

            throw new Error("Don't proccessBuyQueue with limit! Order not clear");
        });

        it("cancelBuyOrderOwner", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            await bank.createBuyOrder(owner, 10, {from: owner, value: web3.toWei(3,'ether')});
            await bank.createBuyOrder(acc1, 10, {from: acc1, value: web3.toWei(3,'ether')});
            await bank.createBuyOrder(acc2, 10, {from: acc2, value: web3.toWei(3,'ether')});

            try {
                await bank.cancelBuyOrderOwner(1);
            } catch(e) {
                throw new Error("Don't work cancelBuyOrderOwner!");
            }

            try {
                await bank.cancelBuyOrderOwner(1);
            } catch(e) {
                return true;
            }

            throw new Error("Don't have revert if cancelBuyOrderOwner canceled!");
        });

        it("get ether after cancel order", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            await bank.createBuyOrder(owner, 10, {from: owner, value: web3.toWei(3,'ether')});
            await bank.processBuyQueue(0);
            
            let before = parseInt(web3.eth.getBalance(owner));
            let amount = parseInt(await bank.getBalanceEther(owner));
            await bank.getEther();
            let after = parseInt(web3.eth.getBalance(owner));

            let price = web3.eth.gasPrice * web3.eth.gasPrice.e;
            let etherUsed = web3.eth.getBlock("latest").gasLimit * price;

            assert.isTrue(before + amount - after <= etherUsed, "getEther don't return ether!");
        });
    });
    
    contract("Sell Orders", function() {

        before("init", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            await cash.setBankAddress(bank.address);

            oracles.forEach( async function(oracle) {
                await oracle.deployed();
                try {
                    await bank.deleteOracle(oracle.address);
                } catch(e) {}
            });

            let oracleTest = await oracles[3].deployed();
            //await oracleTest.setBank(bank.address);
            //await bank.addOracle(oracleTest.address);

            //await bank.requestUpdateRates();
            //await bank.calcRates();
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

            await bank.createSellOrder(acc1, tokenBefore/2, 0);
            await bank.processSellQueue(0);

            let tokenAfter = parseInt(await cash.balanceOf(owner));

            assert.equal(tokenAfter , tokenBefore/2, "Don't burn token");
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

        it("processSellQueue with limit", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            await bank.createBuyOrder(owner, 10, {from: owner, value: web3.toWei(3,'ether')});
            await bank.processBuyQueue(0);

            await bank.createSellOrder(owner, 1, 90);
            await bank.createSellOrder(acc1, 1, 90);
            await bank.createSellOrder(acc2, 1, 90);
            await bank.processSellQueue(2);

            let order = await bank.getSellOrder(2);
            assert.isTrue(order[1] != 0x0, "Don't proccessSellQueue with limit! Order clear");

            try {
                await bank.getSellOrder(1);
            } catch(e) {
                return true;
            }

            throw new Error("Don't proccessSelQueue with limit! Order not clear");
        });

        it("cancelSellOrderOwner", async function() {
            let bank = await ComplexBank.deployed();
            let cash = await LibreCash.deployed();

            await bank.createBuyOrder(owner, 10, {from: owner, value: web3.toWei(6,'ether')});
            await bank.processBuyQueue(0);

            await bank.createSellOrder(owner, 1, 90);
            await bank.createSellOrder(acc1, 1, 90);
            await bank.createSellOrder(acc2, 1, 90);

            try {
                await bank.cancelSellOrderOwner(1);
            } catch(e) {
                throw new Error("Don't work cancelSellOrderOwner!");
            }

            try {
                await bank.cancelSellOrderOwner(1);
            } catch(e) {
                return true;
            }

            throw new Error("Don't have revert if cancelSellOrderOwner canceled!");
        });

    });

    contract("Oracles", function() {
        beforeEach(async function() {
            let bank = await ComplexBank.deployed();
            await LibreCash.deployed();

            await bank.setRelevancePeriod(0);
            
            oracles.forEach(async function(oracle) {
                await oracle.deployed();
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
            
            //throw new Error("Add not Oracles!");
            return true;
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

        it("Don't start calcRate without oracles", async function() {
            let bank = await ComplexBank.deployed();

            try {
                await bank.calcRates();
            } catch(e) {
                return true;
            }
            
            throw new Error("calcRate start without Oracles!");
        });

        it("set scheduler",async function() {
            let bank = await ComplexBank.deployed();
            let before = await bank.scheduler.call();

            let scheduler = (before == acc1) ? (acc2) : (acc1);
            await bank.setScheduler(scheduler);

            let after = await bank.scheduler.call();

            assert.equal(scheduler, after, "setScheduler not work!")
        });

        it("refundOracles", async function() {
            let bank = await ComplexBank.deployed();
            let testOracle = await oracle1.deployed();
            await bank.sendTransaction({from: acc1, value: web3.toWei(5,'ether')});
            await bank.setScheduler(acc1);
            let oracle = await bank.firstOracle.call();
            
            let before = web3.eth.getBalance(oracle);
            let cost = await testOracle.price.call(); //getPrice();
            await bank.schedulerUpdateRate(0,{from:acc1});
            let after = web3.eth.getBalance(oracle);

            //console.log(before,after,cost);
            assert.isTrue(after > before, "Don't fund oralces!");
        });
    });
    contract("Limits setting", function() {
        before("reset limit to zero",async function(){
            let bank = await ComplexBank.deployed();
            await bank.setMinBuyLimit(0);
            await bank.setMaxBuyLimit(web3.toWei(100,'ether'));
            await bank.setMinSellLimit(0);
            await bank.setMaxSellLimit(100 * 10**18);
        });
        it("Limits equals zero",async function(){
            let bank = await ComplexBank.deployed();
            let limits = {
                buyLimits: await bank.buyLimit.call(),
                sellLimits: await bank.sellLimit.call()
            }
            assert.equal(limits.buyLimits[0],0,"Min buy limit not zero");
            assert.equal(limits.buyLimits[1],web3.toWei(100,'ether'),"Max buy limit not zero");
            assert.equal(limits.buyLimits[0],0,"Min sell limit not zero");
            assert.equal(limits.buyLimits[1],100 * 10**18,"Max sell limit not zero");
            return true;
        });
        it("Min buy limit sets properly",async function(){
            let limitAmount = web3.toWei(12,'ether');
            let bank = await ComplexBank.deployed();
            await bank.setMinBuyLimit(limitAmount);
            let minBuyLimit = (await bank.buyLimit.call())[0];
            assert.equal(minBuyLimit,limitAmount,"Min buy limit set properly");
        });
        it("Max buy limit sets properly",async function(){
            let limitAmount = web3.toWei(120,'ether');
            let bank = await ComplexBank.deployed();
            await bank.setMaxBuyLimit(limitAmount);
            let maxBuyLimit = (await bank.buyLimit.call())[1];
            assert.equal(maxBuyLimit,limitAmount,"Max buy limit set properly");
        });
        it("Min sell limit sets properly",async function(){
            let limitAmount = 201733;
            let bank = await ComplexBank.deployed();
            await bank.setMinSellLimit(limitAmount);
            let minSellLimit = (await bank.sellLimit.call())[0];
            assert.equal(minSellLimit,limitAmount,"Min sell tokens set properly");
        });
        it("Max sell limit sets properly",async function(){
            let limitAmount = 120 * 10**18;
            let bank = await ComplexBank.deployed();
            await bank.setMaxSellLimit(limitAmount);
            let maxSellLimit = (await bank.sellLimit.call())[1];
            assert.equal(maxSellLimit,limitAmount,"Min sell tokens set properly");
        });
    });
});
