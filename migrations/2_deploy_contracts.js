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
console.log("console-log-1")
module.exports = async function (deployer, network) {
    const utils = require('./utils.js');
    const deploy = require(`./${network}.js`);

    let contracts = profiles[network].contracts.map((name) => artifacts.require(`./${name}.sol`));

    let config = profiles[network].config || default_config;

    await deploy(deployer, contracts, config);//, web3);

    //if (!/^test.*/.test(network)) {
        console.log("console-log-1-1")
        contracts.forEach(contract => utils.writeContractData(contract));
        console.log("console-log-1-2")
        utils.createMistLoader(contracts);
    //}

    console.log('END DEPLOY');
}; // end module.exports
