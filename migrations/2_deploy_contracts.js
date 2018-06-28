const
    profiles = require('./profiles.js'),
    utils = require('./utils.js'),
    util = require('util');


module.exports = async function (deployer, network) {
    let getCoinbase = util.promisify(web3.eth.getCoinbase);
    const default_config = {
        mintAmount: 100 * 10 ** 18,
        buyFee: 250,
        sellFee: 250,
        deadline: utils.getTimestamp(+5),
        withdrawWallet: await getCoinbase(),
        coinbase: await getCoinbase()
    };
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
