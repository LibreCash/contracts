var LibreCoin = artifacts.require("./LibreCoin.sol");
var SimplexBank = artifacts.require("./SimplexBank.sol");
var OracleBitfinex = artifacts.require("./OracleBitfinex.sol");

module.exports = async function(deployer) {
  await deployer.deploy(LibreCoin);
  var token = await LibreCoin.deployed();
  var tokenAddress = token.address;
  await deployer.deploy(SimplexBank, tokenAddress);
  var bank = await SimplexBank.deployed();
  var bankAddress = bank.address;
  await deployer.deploy(OracleBitfinex, bankAddress);
  var oracle = await OracleBitfinex.deployed();
  var oracleAddress = oracle.address;
  console.log('oracle: ' + oracleAddress);
  await bank.setOracle(oracleAddress);
  console.log('--- setten oracle');
  var oracleRating = await bank.getOracleRating.call();
  console.log('--- oracle rating: ' + oracleRating);
  console.log('token: ' + tokenAddress);
  console.log('bank: ' + bankAddress);

}

/*var LibreBank = artifacts.require("./LibreBank.sol");
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
        let bank;
        LibreBank.deployed().then(function(instance) {
          bank = instance;
          bank.addOracle(oracles['bitfinex']);
          console.log('>>> oracles["bitfinex"] >>> '+oracles['bitfinex']);
          let oracleRating = bank.getOracleRating.call(oracles['bitfinex']);
          return oracleRating;
        }).then(function(oracleRating) {
          console.log('>>> must be 5000 >>> '+oracleRating);
        });
      });
//      deployer.deploy(OracleBitstamp, bankAddress).then(function() {
//        oracles['bitstamp'] = OracleBitstamp.address;
//        console.log(oracles);
//      });    
//      deployer.deploy(OracleGDAX, bankAddress).then(function() {
//        oracles['gdax'] = OracleGDAX.address;
//        console.log(oracles);
//      });
    });
  });
};*/