const
    exchangerDeploy = require('./exchanger.js'),
    contractConfig = require('./config.js');

module.exports = async function (deployer, contracts, config) {
    let [cash, exchanger, deposit, ...oracles] = contracts;

    await exchangerDeploy(deployer, [cash, exchanger, ...oracles], config);
    let _cash = await cash.deployed();

    await deployer.deploy(deposit, cash.address);
    
    await _cash.mint.sendTransaction(deposit.address, contractConfig.Deposit.mintAmount);
    await _cash.approve.sendTransaction(deposit.address, contractConfig.Deposit.approveAmount);
};
