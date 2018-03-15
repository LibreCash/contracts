const
    reverter = new (require('./helpers/reverter'))(web3),
    timeMachine = new (require('./helpers/timemachine'))(web3),
    assertTx = new (require('./helpers/assertTx'))(),
    utils = new (require('./helpers/utils'))(),
    tokenMultiplier = Math.pow(10, 18),
    MORE_THAN_COSTS = web3.toWei(5,'ether');

var ComplexBank = artifacts.require("ComplexBank"),
    LibreCash = artifacts.require("LibreCash"),
    Association = artifacts.require("Association"),
    Liberty = artifacts.require("LibertyToken");


const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

contract('Association', function(accounts) {
    var owner = accounts[0],
        acc1  = accounts[1],
        bank,
        token,
        liberty,
        association,
        minimumQuorum,
        minDebatingPeriodInMinutes;

    before("init var", async function() {
        bank = await ComplexBank.deployed();
        token = await LibreCash.deployed();
        liberty = await Liberty.deployed();
        association = await Association.deployed();
        minimumQuorum = await association.minimumQuorum.call();
        minDebatingPeriodInMinutes = await association.minDebatingPeriodInMinutes.call();
    });

    context("check links", function() {
        it("association addresses", async function() {
            assert.equal(bank.address, await association.bank.call(),"Address bank not right!");
            assert.equal(token.address, await association.cash.call(),"Address token not right!");
            assert.equal(liberty.address, await association.sharesTokenAddress.call(),"Address liberty not right!");
            assert.equal(association.address, await bank.owner.call(),"Address owner in bank not right!");
        });
    });

    context("Proposals", function() {

        before("init", reverter.snapshot);
        afterEach("revert", reverter.revert);

        it("TransferOwnership", async function() {
            let id = +await association.proposalsLength.call();
            await association.proposalTransferOwnership(owner,"Hello",minDebatingPeriodInMinutes);
            await association.vote(id,true);
            timeMachine.jump(minDebatingPeriodInMinutes +1);
            await association.executeProposal(id);

            assert(owner, await bank.owner.call(), "Proposal not set new owner!");
        });
    });

});