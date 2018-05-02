const bankDeploy = require('./bank.js');

module.exports = async function(deployer, contracts, config) {
    let [cash, bank, association, liberty, ...oracles] = contracts;

    await deployer.deploy(liberty);
    await bankDeploy(deployer, [cash, bank, ...oracles], config);

    await deployer.deploy(
        association,
        /* Constructor params */
        liberty.address,
        bank.address,
        cash.address,
        consig["Association"].minimumSharesToPassAVote,
        consig["Association"].minSecondsForDebate
    );

    let _bank = await bank.deployed();
    await _bank.transferOwnership(association.address)
}