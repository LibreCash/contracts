const 
    daoDeploy = require('./dao.js'),
    contractConfig = require('./config.js');

module.exports = async function(deployer, contracts, config) {
    let [cash, bank, association, liberty, faucet, ...oracles] = contracts;

    await daoDeploy(deployer, [cash, bank, association, liberty, ...oracles], config);
    await deployer.deploy(faucet, liberty.address);

    let _liberty = await liberty.deployed();
    await _liberty.transfer.sendTransaction(faucet.address,contractConfig["Faucet"].libretyAmount);
}