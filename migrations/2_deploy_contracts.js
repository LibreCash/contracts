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
    //console.log("!!!token:" + tokenAddress);
    deployer.deploy(LibreBank, tokenAddress).then(function() {
      var bankAddress = LibreBank.address;
      //console.log("!!!bank:" + bankAddress);

      deployer.deploy(OracleBitfinex, bankAddress);
      deployer.deploy(OracleBitstamp, bankAddress);    
      deployer.deploy(OracleGDAX, bankAddress);
      deployer.deploy(OracleGemini, bankAddress);    
      deployer.deploy(OracleKraken, bankAddress);
      deployer.deploy(OracleWEX, bankAddress);
    });
  });
};