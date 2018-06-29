const
    bankDeploy = require('./bank.js'),
    contractConfig = require('./config.js');

module.exports = async function (deployer, contracts, config) {
    let
        onlyAssociation = true,
        [cash, bank, association, liberty, ...oracles] = contracts;
    if(!onlyAssociation) {
        await bankDeploy(deployer, [cash, bank, ...oracles], config);
    }

    await deployer.deploy(liberty);
    await deployer.deploy(
        association,
        /* Constructor params */
        liberty.address,
        contractConfig.Association.minimumSharesToPassAVote,
        contractConfig.Association.minSecondsForDebate,
        1
    );
    
    var _liberty = await liberty.deployed();
    var _association = await association.deployed();
    await _liberty.approve(association.address, 100000 * 10**18);
    await _association.lock(3000 * 10**18);

    if(!onlyAssociation) {
        let _bank = await bank.deployed();
        await _bank.transferOwnership(association.address);
    }
};
