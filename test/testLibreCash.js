var LibreCash = artifacts.require("LibreCash");

contract('LibreCash', function(accounts) {

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
        await cash.setBankAddress(accounts[0]);
        let result = await cash.bankAddress.call();

        assert.equal(result, accounts[0], "bankAddress not set");
    });

    it("minigin test", async function() {
        let amount = 10;
        
        let cash = await LibreCash.deployed();
        console.log(await cash.bankAddress.call());
        let befor = await cash.getTokensAmount.call();
        await cash.mint(accounts[0], amount);
        let after = await cash.getTokensAmount.call();

        assert.equal(befor + amount, after, "bankAddress not set");
    });

});
