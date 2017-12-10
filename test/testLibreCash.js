var LibreCash = artifacts.require("LibreCash");

contract('LibreCash', async function(accounts) {
    var owner = accounts[0];
    var acc1  = accounts[1];
    var acc2  = accounts[2];

    contract('#setBankAddress', function() {

        it("check to set 0x0 bankAddress", async function() {
            let cash = await LibreCash.deployed();

            try {
                await cash.setBankAddress("0x0");
            } catch(e) {
                return true;
            }
            throw new Error("Address can not be 0x0!");
        });

        it("set-get bankAddress", async function() {
            let cash = await LibreCash.deployed();
            let acc = acc1;

            let currAcc = await cash.bankAddress.call();
            if (acc === currAcc) {
                acc = acc2;
            }
            await cash.setBankAddress(acc);
            let result = await cash.bankAddress.call();
    
            assert.equal(result, acc, "bankAddress not set");
        });
    });
    
    contract('#mint', function() {

        beforeEach(async function() {
            let cash = await LibreCash.deployed();
            await cash.setBankAddress(owner);
        });

        it("tokens amount", async function() {
            let cash = await LibreCash.deployed();
            let amount = 100;
            
            let before = await cash.totalSupply();
            await cash.mint(owner, amount);
            let after = parseInt(await cash.totalSupply.call());

            assert.equal(before + amount, after, "minting didn't happen");
        });

        it("minting to account", async function() {
            let cash = await LibreCash.deployed();
            let amount = 50;

            let before = parseInt(await cash.balanceOf(acc1));
            await cash.mint(acc1, amount);
            let after = parseInt(await cash.balanceOf(acc1));

            assert.equal(before + amount, after, "minting don't added to account");
        });
    
        it("Other dont have permission to minting", async function() {
            let cash = await LibreCash.deployed();
            await cash.setBankAddress(acc1);

            try {
                await cash.mint(acc2, 10);
            } catch(e) {
                return true;
            }
    
            throw new Error("Account mint without permissions!");
        });
    });

    contract("#StandartToken", function() {
        before("init", async function() {
            let cash = await LibreCash.deployed();
            await cash.setBankAddress(owner);

            await cash.mint(owner, 10);
            await cash.mint(acc1, 11);
            await cash.mint(acc2, 12);
        });

        it("transfer", async function() {
            let cash = await LibreCash.deployed();
            
            let acc1Before = parseInt(await cash.balanceOf(acc1));
            let acc2Before = parseInt(await cash.balanceOf(acc2));

            let amount = Math.round(acc1Before/2);
            await cash.transfer(acc2, amount, {from: acc1});

            let acc1After = parseInt(await cash.balanceOf(acc1));
            let acc2After = parseInt(await cash.balanceOf(acc2));

            assert.equal(acc1Before - amount, acc1After, "Sender balance not decrease");
            assert.equal(acc2Before + amount, acc2After, "Receiver balance not increase");
        });

        it("allowance", async function() {
            let cash = await LibreCash.deployed();

            let balanceOne = parseInt(await cash.balanceOf(acc1));
            let balanceTwo = parseInt(await cash.balanceOf(acc2));

            let allowanceBefore = parseInt(await cash.allowance(acc1,acc2));
            let amount = Math.round(balanceOne/2);

            await cash.approve(acc2,amount, {from: acc1});

            let allowanceAfter = parseInt(await cash.allowance(acc1,acc2));

            try {
                await cash.transferFrom(acc1,acc2,amount, {from: acc2});
            } catch(e) {
                throw new Error("Account don't transferFrom!");
            }
            assert.equal(allowanceBefore + amount, allowanceAfter, "Allowance not work!");
        });
    });

});
