const _default = {
    host: "localhost",
    port: 8545,
    network_id: "dev",
    gas: 6000000
}

module.exports = {
  networks: {
    development: _default,
    mainnet: {
      network_id: "mainnet", // rinkeby, ropsten, main network, etc.
      host: "localhost",
      port: 8545,
      gas: 6000000 // чтобы деплоилось - править когда gas limit ему не нравится (дефолт вроде как 4712388, и с ним ошибка)
    },
    testBank: _default,
    testExchanger: _default,
    testDAO: _default
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