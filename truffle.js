module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "dev", // local
      gas: 6000000
    },
    mainnet: {
      network_id: "mainnet", // rinkeby, ropsten, main network, etc.
      host: "localhost",
      port: 8545,
      gas: 6000000
    },
    // Network used to detect necessery dependencies for testing purposes
    testBank: {
      host: "localhost",
      port: 8545,
      network_id: "dev",
      gas: 6000000
    },
    // Network used to detect necessery dependencies for testing purposes
    testExchanger: {
      host: "localhost",
      port: 8545,
      network_id: "dev",
      gas: 6000000
    },
    // Network used to detect necessery dependencies for testing purposes
    
    testDAO: {
      host: "localhost",
      port: 8545,
      network_id: "dev",
      gas: 6000000
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