const oraclesDeploy = require('./oracles.js'),
      contractConfig = require('./config.js');

module.exports = async function(deployer, contracts, config) {
    let [cash, exchanger, loans, deposit,...oracles] = contracts;

    deployer.deploy(cash).then(async() => {
        await Promise.all(oracles.map((oracle) => deployer.deploy(oracle, 0)))
        let _oracles = await Promise.all(oracles.map((oracle) => oracle.deployed()))
        let oraclesAddress = oracles.map((oracle) => oracle.address);

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

        await deployer.deploy(loans, cash.address, exchanger.address);

        await deployer.deploy(deposit, cash.address);
    
        await _cash.mint.sendTransaction(deposit.address, contractConfig["Deposit"].mintAmount)
        await _cash.approve.sendTransaction(deposit.address, contractConfig["Deposit"].approveAmount)
    }).then(() => console.log("END DEPLOY TEST"))
    
}