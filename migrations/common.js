const
    bankDeploy = require('./bank.js'),
    contractConfig = require('./config.json');

module.exports = async function (deployer, contracts, config) {
    let [cash, bank, association, liberty, loans, deposit, faucet, ...oracles] = contracts;

    await deployer.deploy(liberty);
    await bankDeploy(deployer, [cash, bank, ...oracles], config);

    await deployer.deploy(
        association,
        /* Constructor params */
        liberty.address,
        bank.address,
        cash.address,
        contractConfig.Association.minimumSharesToPassAVote,
        contractConfig.Association.minSecondsForDebate
    );

    let _bank = await bank.deployed();
    await _bank.transferOwnership(association.address);

    await deployer.deploy(deposit, cash.address);
    let _cash = await cash.deployed();
    
    await _cash.mint.sendTransaction(deposit.address, contractConfig.Deposit.mintAmount);
    await _cash.approve.sendTransaction(deposit.address, contractConfig.Deposit.approveAmount);

    await deployer.deploy(loans, cash.address, bank.address);

    await deployer.deploy(faucet, liberty.address);
    let _liberty = await liberty.deployed();
    await _liberty.transfer.sendTransaction(faucet.address, contractConfig.Faucet.libretyAmount);
};
