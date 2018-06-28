require('dotenv').config();
const
    HDWalletProvider = require('truffle-hdwallet-provider'),
    profiles = require('./migrations/profiles.js'),
    providerWithMnemonic = (mnemonic, rpcEndpoint) => new HDWalletProvider(mnemonic, rpcEndpoint),
    infuraProvider = (network) => providerWithMnemonic(
        process.env.MNEMONIC || '',
        `https://${network}.infura.io/${process.env.INFURA_API_KEY}`
    ),
    infuraNetworks = [
        { name: 'rinkeby', id:4 },
        { name: 'mainnet', id:1 },
        { name: 'kovan', id: 42 },
        { name: 'ropsten', id:3 }
    ],
    infuraProviders = {};
    infuraNetworks.forEach((network) => { infuraProviders[network.name] = {provider:infuraProvider(network.name), id:network.id} });

var
    networks = {},
    defaultNetwork = !process.env.DEFAULT_NETWORK ? 'rinkeby' : process.env.NETWORK_NAME,
    isLocal = process.env.NETWORK_NAME === 'local',
    networkName = process.env.NETWORK_NAME;
    console.log(networkName);
if (!isLocal) {

    infuraProviders["rinkeby"].provider.getAddress(console.log());

    var curNetwork = { // eslint-disable-line
        provider: infuraProviders[networkName].provider || infuraProvider[defaultNetwork].provider,
        network_id: infuraProviders[networkName].id, // eslint-disable-line camelcase
        gas: process.env.GAS_LIMIT || 6000000,
        gasPrice: process.env.GAS_PRICE || 5000000000, // 5gwei
    };
    console.log(networks);
}

Object.keys(profiles).forEach(network => { networks[network] = isLocal ? profiles[network].network : curNetwork; });
console.log(networks)
module.exports = {
    networks,

    // add a section for mocha defaults
    mocha: {
        reporter: 'spec',
        reporterOptions: {
            mochaFile: 'TEST-truffle.xml',
        },
    },
    // enables SOLC compiler optimization (reduce gas usage)
    solc: {
        optimizer: {
            enabled: true,
            runs: 200,
        },
    },
};
