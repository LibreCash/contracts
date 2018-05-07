require('dotenv').config();
var
    profiles = require('./migrations/profiles.js'),
    networks = {};
    /*
     
    HDWalletProvider = require('truffle-hdwallet-provider');
    providerWithMnemonic = (mnemonic, rpcEndpoint) => new HDWalletProvider(mnemonic, rpcEndpoint),
    infuraProvider = (network) => providerWithMnemonic(
        process.env.MNEMONIC || '',
        `https://${network}.infura.io/${process.env.INFURA_API_KEY}`
    ),
    ropstenProvider = process.env.SOLIDITY_COVERAGE ? undefined : infuraProvider('ropsten'),
    rinkebyProvider = process.env.SOLIDITY_COVERAGE ? undefined : infuraProvider('ropsten'); */

Object.keys(profiles).forEach(network => { networks[network] = profiles[network].network; });
/* networks["coverage"] = { // eslint-disable-line
    host: 'localhost',
    network_id: '*', // eslint-disable-line camelcase
    port: 8555,
    gas: 0xfffffffffff,
    gasPrice: 0x01,
};

networks["ropsten"] = { // eslint-disable-line
    provider: ropstenProvider,
    network_id: 3, // eslint-disable-line camelcase
};

networks["rinkeby"] = { // eslint-disable-line
    provider: rinkebyProvider,
    network_id: '*', // eslint-disable-line camelcase
};
*/
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
