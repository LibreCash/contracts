module.exports = {
  networks: {
    // Local node (eg.testrpc)
    // Deploy mocked oracles
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*",
      gasPrice: 100000000000,
      gas: 6000000
    },
    // ETH Main Network
    // Deploy Oraclize oracles
    // Also gas price is lower (decrease deploy cost)
    mainnet: {
      network_id: "*", // rinkeby, ropsten, main network, etc.
      gasPrice: 20000000000, //  20 Gwei 
      host: "localhost",
      port: 8545,
      gas: 6000000
    },
	  // ETH Test Network (eg Ropsten or Rinkeby)
	  // Deploy Oraclize oracles
    testnet: {
        network_id: "*", // rinkeby, ropsten, main network, etc.
        gasPrice: 50000000000, //  50 Gwei 
        host: "localhost",
        port: 8545,
        gas: 6000000
      }
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
}