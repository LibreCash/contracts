const
    profiles = require('./profiles.js'),
    configContract = require('./config.js'),
    utils = require('./utils.js');

module.exports = async function (deployer, network) {
    const deploy = require(`./${network}.js`);

    let contracts = profiles[network].contracts.map((name) => artifacts.require(`./${name}.sol`));
    let config = profiles[network].config || configContract.Exchanger;

    await deploy(deployer, contracts, config);

    if (!/^test.*/.test(network)) {
        contracts.forEach(contract => utils.writeContractData(contract));
        utils.createMistLoader(contracts);
    }

    console.log('END DEPLOY');
}; // end module.exports
