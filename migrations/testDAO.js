module.exports = async function (deployer, contracts, config) {
    let [cash, bank, association, liberty, ...oracles] = contracts;

    deployer.deploy(cash).then(async () => {
        await deployer.deploy(liberty);

        await Promise.all(oracles.map((oracle) => deployer.deploy(oracle, 0)));
        let _oracles = await Promise.all(oracles.map((oracle) => oracle.deployed()));
        let oraclesAddress = oracles.map((oracle) => oracle.address);
        let _cash = await cash.deployed();

        await deployer.deploy(
            bank,
            /* Constructor params */
            cash.address, // Token address
            config.buyFee, // Buy Fee
            config.sellFee, // Sell Fee,
            oraclesAddress, // oracles (array of address)
        );
        let _bank = await bank.deployed();

        await Promise.all(_oracles.map((oracle) => oracle.setBank(bank.address)));

        await _cash.mint.sendTransaction(config.withdrawWallet, 1000 * 10 ** 18);

        await _cash.transferOwnership(bank.address);
        await _bank.claimOwnership();

        await deployer.deploy(
            association,
            /* Constructor params */
            liberty.address,
            bank.address,
            cash.address,
            /* minimumSharesToPassAVote: */ 10000 * 10 ** 18,
            /* minSecondsForDebate: */ 6 * 60 * 60
        );

        await _bank.transferOwnership(association.address);
    }).then(() => console.log('END DEPLOY TEST')).catch((e) => { console.log(JSON.stringify(e)); }); ;
};