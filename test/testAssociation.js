const
    reverter = new (require('./helpers/reverter'))(web3),
    timeMachine = new (require('./helpers/timemachine'))(web3),
    assertTx = new (require('./helpers/assertTx'))(),
    utils = new (require('./helpers/utils'))(),
    tokenMultiplier = Math.pow(10, 18),
    MORE_THAN_COSTS = web3.toWei(5, 'ether');

var ComplexBank = artifacts.require('ComplexBank'),
    LibreCash = artifacts.require('LibreCash'),
    Association = artifacts.require('Association'),
    Liberty = artifacts.require('LibertyToken');

var TypeProposal = {
    'UNIVERSAL': 0,
    'TRANSFER_OWNERSHIP': 1,
    'ATTACH_TOKEN': 2,
    'SET_BANK_ADDRESS': 3,
    'SET_FEES': 4,
    'ADD_ORACLE': 5,
    'DISABLE_ORACLE': 6,
    'ENABLE_ORACLE': 7,
    'DELETE_ORACLE': 8,
    'SET_SCHEDULER': 9,
    'WITHDRAW_BALANCE': 10,
    'SET_ORACLE_TIMEOUT': 11,
    'SET_ORACLE_ACTUAL': 12,
    'SET_RATE_PERIOD': 13,
    'SET_PAUSED': 14,
    'CLAIM_OWNERSHIP': 15,
    'CHANGE_ARBITRATOR': 16,
};

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

contract('Association', function (accounts) {
    var owner = accounts[0],
        acc1 = accounts[1],
        bank,
        token,
        liberty,
        association,
        minimumQuorum,
        minDebatingPeriod;

    before('init var', async function () {
        bank = await ComplexBank.deployed();
        token = await LibreCash.deployed();
        liberty = await Liberty.deployed();
        association = await Association.deployed();
        minimumQuorum = await association.minimumQuorum();
        minDebatingPeriod = await association.minDebatingPeriod();
    });

    context('check links', function () {
        it('association addresses', async function () {
            assert.equal(bank.address, await association.bank.call(), 'Address bank not right!');
            assert.equal(token.address, await association.cash.call(), 'Address token not right!');
            assert.equal(liberty.address, await association.sharesTokenAddress.call(), 'Address liberty not right!');
            assert.equal(association.address, await bank.owner.call(), 'Address owner in bank not right!');
        });
    });

    context('Proposals', function () {
        before('init', reverter.snapshot);
        afterEach('revert', reverter.revert);

        it.skip('TransferOwnership', async function () {
            let id = +await association.prsLength();
            await association.newProposal(TypeProposal.TRANSFER_OWNERSHIP, owner, 0, 0, 'Hello', 0, 0);
            await association.vote(id, true);
            timeMachine.jump(minDebatingPeriod + 1);
            await association.executeProposal(id);

            assert(owner, await bank.owner.call(), 'Proposal not set new owner!');
        });
    });
});
