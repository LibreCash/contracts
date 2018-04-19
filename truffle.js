module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "dev", // local
      gas: 6000000 // чтобы деплоилось - править когда gas limit ему не нравится (дефолт вроде как 4712388, и с ним ошибка)
      // https://github.com/trufflesuite/truffle/issues/271
    },
    mainnet: {
      network_id: "mainnet", // rinkeby, ropsten, main network, etc.
      host: "localhost",
      port: 8545,
      gas: 6000000 // чтобы деплоилось - править когда gas limit ему не нравится (дефолт вроде как 4712388, и с ним ошибка)
    },
    testBank: {
      host: "localhost",
      port: 8545,
      network_id: "dev",
      gas: 6000000
    },
    testExchanger: {
      host: "localhost",
      port: 8545,
      network_id: "dev",
      gas: 6000000
    },
    testDAO: {
      host: "localhost",
      port: 8545,
      network_id: "dev",
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