module.exports = async function(deployer, contracts, config) {
    let [cash, exchanger, ...oracles] = contracts;

    await Promise.all(oracles.map((oracle) => deployer.deploy(oracle)))
    let _oracles = await Promise.all(oracles.map((oracle) => oracle.deployed()))
    let oraclesAddress = oracles.map((oracle) => oracle.address);

    await deployer.deploy(cash);
    let _cash = await cash.deployed();

    await deployer.deploy(
        exchanger,
        /*Constructor params*/
        cash.address, // Token address
        config.buyFee, // Buy Fee
        config.sellFee, // Sell Fee,
        oraclesAddress,// oracles (array of address)
        config.deadline,
        config.withdrawWallet
    );
    let _exchanger = await exchanger.deployed();

    await Promise.all(_oracles.map((oracle) => oracle.setBank(exchanger.address)));

    await _cash.mint.sendTransaction(exchanger.address, 100 * 10 ** 18);
    await _cash.mint.sendTransaction(config.withdrawWallet, 1000 * 10 ** 18);
}