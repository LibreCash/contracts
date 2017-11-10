var LibreCash = artifacts.require("LibreCash");

contract('LibreCash', async function(accounts) {
    var owner = accounts[0];
    var acc1 = accounts[1];
    var acc2 = accounts[2];

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
            await cash.setBankAddress(acc1);
        });

        it("minting bank", async function() {
            let cash = await LibreCash.deployed();
            let amount = 100;
            
            let befor = await cash.getTokensAmount();
            return true;
            await cash.mint(acc1, amount);
            return true;
            let after = await cash.getTokensAmount.call();
            let accAmmount = await cash.balanceOf(acc1);
            console.log(after);
    
            assert.equal(befor + amount, after, "minig didn't happen");
            //assert.equal(amount, accAmmount, "minig don't added");
        });
    
        it("Other dont have permission to minting", async function() {
            let cash = await LibreCash.deployed();
    
            let bankAddress = await cash.bankAddress.call();
            let acc2 = accounts[1];
            let acc3 = accounts[2];
            if (bankAddress === acc2) {
                acc2 = accounts[1];
            }
            try {
                await cash.mint(acc2, 10);
            } catch(e) {
                return true;
            }
    
            throw new Error("Account mint without permissions!");
        });
    });

});
