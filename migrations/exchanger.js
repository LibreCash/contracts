const
    oraclesDeploy = require('./oracles.js'),
    contractConfig = require('./config.js');

module.exports = async function (deployer, contracts, config) {
    let [cash, exchanger, ...oracles] = contracts;

    await oraclesDeploy(deployer, oracles);
    let _oracles = await Promise.all(oracles.map((oracle) => oracle.deployed()));
    let oraclesAddress = oracles.map((oracle) => oracle.address);

    await deployer.deploy(cash);
    let _cash = await cash.deployed();

    await deployer.deploy(
        exchanger,
        /* Constructor params */
        cash.address, // Token address
        config.buyFee, // Buy Fee
        config.sellFee, // Sell Fee,
        oraclesAddress, // oracles (array of address)
        config.deadline,
        "0x0124cEEa90258dC124b698f3C88fee8eec0c3d10"
    );
    
    await exchanger.deployed();
    console.log("console-log-2-1")
    await Promise.all(_oracles.map((oracle) => oracle.setBank(exchanger.address)));
    console.log("console-log-2-2")
    await _cash.mint.sendTransaction(exchanger.address, contractConfig.Exchanger.mintAmount);
    await _cash.mint.sendTransaction("0x0124cEEa90258dC124b698f3C88fee8eec0c3d10", contractConfig.main.cashMinting);
};
