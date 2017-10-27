module.exports = {
  networks: {
    development: {
      host: "localhost",
      //port: 9000, // testrpc (у меня - Дима)
      port: 8545,
      network_id: "*", // Match any network id
      gas: 4612388 // чтобы деплоилось - править когда gas limit ему не нравится (дефолт вроде как 4712388, и с ним ошибка)
      // https://github.com/trufflesuite/truffle/issues/271
    }
  },
  // add a new network definition that will self host TestRPC
/*localtest: {
  provider: TestRPC.provider(),
  network_id:"*"
  },*/
   
  // add a section for mocha defaults
  mocha: {
    reporter: "spec",
    reporterOptions: {
      mochaFile: 'TEST-truffle.xml'
    }
  }
}
