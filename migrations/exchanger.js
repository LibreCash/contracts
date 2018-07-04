const
    oraclesDeploy = require('./oracles.js'),
    contractConfig = require('./config.js');

module.exports = async function (deployer, contracts, config) {
    let [store, feed, cash, exchanger, ...oracles] = contracts;

    await oraclesDeploy(deployer, oracles);
    let _oracles = await Promise.all(oracles.map((oracle) => oracle.deployed()));
    let oraclesAddress = oracles.map((oracle) => oracle.address);

    await deployer.deploy(cash);
    let _cash = await cash.deployed();

    await deployer.deploy(store, oraclesAddress);
    let _store = await store.deployed;

    await deployer.deploy(feed, store.address);
    let _feed = await feed.deployed;

    await deployer.deploy(
        exchanger,
        /* Constructor params */
        cash.address, // Token address
        config.buyFee, // Buy Fee
        config.sellFee, // Sell Fee,
        feed.address, // Oracle Feed
        config.deadline,
        config.withdrawWallet
    );
    await exchanger.deployed();

    await Promise.all(_oracles.map((oracle) => oracle.setBank(feed.address)));

    await _cash.mint.sendTransaction(exchanger.address, contractConfig.Exchanger.mintAmount);
    await _cash.mint.sendTransaction(config.coinbase, contractConfig.main.cashMinting);
};
