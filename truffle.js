module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "dev", // local
      gas: 4612388 // чтобы деплоилось - править когда gas limit ему не нравится (дефолт вроде как 4712388, и с ним ошибка)
      // https://github.com/trufflesuite/truffle/issues/271
    },
    mainnet: {
      network_id: "mainnet", // rinkeby, ropsten, main network, etc.
      host: "localhost",
      port: 8545,
      gas: 4612388 // чтобы деплоилось - править когда gas limit ему не нравится (дефолт вроде как 4712388, и с ним ошибка)
    }
  },
   
  // add a section for mocha defaults
  mocha: {
    reporter: "spec",
    reporterOptions: {
      mochaFile: 'TEST-truffle.xml'
    }
  }
}