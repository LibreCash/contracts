const
    profiles = require('./profiles.js'),
    utils = require('./utils.js'),
    default_config = {
        mintAmount: 100 * 10 ** 18,
        buyFee: 250,
        sellFee: 250,
        deadline: utils.getTimestamp(+5),
        withdrawWallet: web3.eth.coinbase,
        coinbase: web3.eth.coinbase
    };

module.exports = async function (deployer, network) {
    const deploy = require(`./${network}.js`);

    let contracts = profiles[network].contracts.map((name) => artifacts.require(`./${name}.sol`));
    let config = profiles[network].config || default_config;

    await deploy(deployer, contracts, config);

    if (!/^test.*/.test(network)) {
        contracts.forEach(contract => utils.writeContractData(contract));
        utils.createMistLoader(contracts);
    }

    console.log('END DEPLOY');
}; // end module.exports
