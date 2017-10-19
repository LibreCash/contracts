var LibreCoin = artifacts.require("./LibreCoin.sol");
var LibreBank = artifacts.require("./LibreBank.sol");
var OracleBitfinex = artifacts.require("./OracleBitfinex.sol");
var OracleBitstamp = artifacts.require("./OracleBitstamp.sol");
var OracleGDAX = artifacts.require("./OracleGDAX.sol");
var OracleGemini = artifacts.require("./OracleGemini.sol");
var OracleKraken = artifacts.require("./OracleKraken.sol");
var OracleWEX = artifacts.require("./OracleWEX.sol");

module.exports = function(deployer) {
  deployer.deploy(LibreCoin).then(function() {
    var tokenAddress = LibreCoin.address;
    deployer.deploy(LibreBank, tokenAddress).then(function() {
      let bankAddress = LibreBank.address;
    
      let oracles = {};
      deployer.deploy(OracleBitfinex, bankAddress).then(function() {
        oracles['bitfinex'] = OracleBitfinex.address;
        let bank; LibreBank.deployed().then(function(instance) {
          console.log('++++++++++++ librebank.deployed.then ++++++++');
          bank = instance;
          bank.addOracle(oracles['bitfinex']);
          console.log('==========='+bank.getOracleName(oracles['bitfinex']);
        });
      });
/*      deployer.deploy(OracleBitstamp, bankAddress).then(function() {
        oracles['bitstamp'] = OracleBitstamp.address;
        console.log(oracles);
      });    
      deployer.deploy(OracleGDAX, bankAddress).then(function() {
        oracles['gdax'] = OracleGDAX.address;
        console.log(oracles);
      });*/
    });
  });
};