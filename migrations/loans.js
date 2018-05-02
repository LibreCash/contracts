const exchangerDeploy = require('./exchanger.js');

module.exports = async function(deployer, contracts, config) {
    let [cash, exchanger, loans, ...oracles] = contracts;

    await exchangerDeploy(deployer, [cash, exchanger, ...oracles], config);
    await deployer.deploy(loans, cash.address, exchanger.address);
}