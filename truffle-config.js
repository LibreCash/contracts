require('dotenv').config();
var 
      profiles = require("./migrations/profiles.js"),
      networks = {},
      HDWalletProvider = require('truffle-hdwallet-provider');
      providerWithMnemonic = (mnemonic, rpcEndpoint) =>
        new HDWalletProvider(mnemonic, rpcEndpoint),
      infuraProvider = network => providerWithMnemonic(
        process.env.MNEMONIC || '',
        `https://${network}.infura.io/${process.env.INFURA_API_KEY}`
      );      

Object.keys(profiles).forEach(network => networks[network] = profiles[network].network)

module.exports = {

  networks["coverage"] = {
      host: 'localhost',
      network_id: '*', // eslint-disable-line camelcase
      port: 8555,
      gas: 0xfffffffffff,
      gasPrice: 0x01,
  },
  networks['ropsten'] = {
      provider: ropstenProvider,
      network_id: 3, // eslint-disable-line camelcase
  },

   
  // add a section for mocha defaults
  mocha: {
    reporter: "spec",
    reporterOptions: {
      mochaFile: 'TEST-truffle.xml'
    }
  },
  // enables SOLC compiler optimization (reduce gas usage)
  solc: {
     optimizer: {
     enabled: true,
     runs: 200
   }
 }
};