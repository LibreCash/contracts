const exchangerDeploy = require('./exchanger.js');

module.exports = async function(deployer, contracts, config) {
    let [cash, exchanger, deposit, ...oracles] = contracts;

    await exchangerDeploy(deployer, [cash, exchanger, ...oracles], config);
    let _cash = await cash.deployed()

    await deployer.deploy(deposit, cash.address);
    
    await _cash.mint.sendTransaction(deposit.address, 10000 * 10 ** 18)
    await _cash.approve.sendTransaction(deposit.address, 10000 * 10 ** 18)
}