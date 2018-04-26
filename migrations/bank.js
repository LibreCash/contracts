module.exports = async function(deployer, contracts, config) {
    let [cash, bank, ...oracles] = contracts;

    await Promise.all(oracles.map((oracle) => deployer.deploy(oracle)))
    let _oracles = await Promise.all(oracles.map((oracle) => oracle.deployed()))
    let oraclesAddress = oracles.map((oracle) => oracle.address);

    await deployer.deploy(cash);
    let _cash = await cash.deployed();

    await deployer.deploy(
        bank,
        /*Constructor params*/
        cash.address, // Token address
        config.buyFee, // Buy Fee
        config.sellFee, // Sell Fee,
        oraclesAddress,// oracles (array of address)
    );
    let _bank = await bank.deployed();

    await Promise.all(_oracles.map((oracle) => oracle.setBank(bank.address)));

    await _cash.mint.sendTransaction(config.withdrawWallet, 1000 * 10 ** 18);

    await _cash.transferOwnership(bank.address);
    await _bank.claimOwnership()
}