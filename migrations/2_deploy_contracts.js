var LibreCoin = artifacts.require("./LibreCoin.sol");
var LibreBank = artifacts.require("./LibreBank.sol");
var OracleBitfinex = artifacts.require("./OracleBitfinex.sol");
//var OracleKraken = artifacts.require("./OracleKraken.sol");

module.exports = function(deployer) {
  /*deployer.deploy(LibreCoin).then(function(){
    deployer.deploy(LibreBank, 0x0);
  });;*/
  deployer.deploy(LibreCoin);
  deployer.deploy(LibreBank, 0x0); // сюда адрес LibreCoin, возможно нужно в промис как выше в комментированном коде
  deployer.deploy(OracleBitfinex);
  //deployer.deploy(OracleKraken);
  
};