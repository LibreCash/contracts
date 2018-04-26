const profiles = require("./migrations/profiles.js")
      networks = {};

Object.keys(profiles).forEach(network => networks[network] = profiles[network].network)

module.exports = {
  networks,
   
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