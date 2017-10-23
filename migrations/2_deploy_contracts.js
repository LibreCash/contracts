var contractsToDeploy = array();
contractsToDeploy[] = artifacts.require("./LibreCash.sol");
contractsToDeploy[] = artifacts.require("./SimplexBank.sol");
contractsToDeploy[] = artifacts.require("./OracleBitfinex.sol");
contractsToDeploy[] = artifacts.require("./OracleBitstamp.sol");
contractsToDeploy[] = artifacts.require("./OracleGDAX.sol");
contractsToDeploy[] = artifacts.require("./OracleGemini.sol");
contractsToDeploy[] = artifacts.require("./OracleKraken.sol");
contractsToDeploy[] = artifacts.require("./OracleWEX.sol");



/*var LibreCash = artifacts.require("./LibreCash.sol");
var SimplexBank = artifacts.require("./SimplexBank.sol");
var OracleBitfinex = artifacts.require("./OracleBitfinex.sol");
*/
var http = require('http');

var contractsToDeploy = [LibreCash, SimplexBank, OracleBitfinex];

Date.prototype.timeNow = function () {
  return ((this.getHours() < 10)?"0":"") + this.getHours() +":"+ ((this.getMinutes() < 10)?"0":"") + this.getMinutes() +":"+ ((this.getSeconds() < 10)?"0":"") + this.getSeconds();
}

function Log(anything) {
  console.log((new Date()).timeNow() + ' [deploy] ' + anything);
}

function sendDeployedContractData(contract) {
  var gateUrl = "http://traf1.ru/libreGate/gate.php";
//  var contractName = contract.name; // проверить
//  var contractAddress = contract.address;
//  var contractABI = contract._json.abi;
  var post_data = "contractName=" + "name" + "&contractAddress=" + "address" + "&contractABI=" + Buffer.from("ABI").toString("base64");;
  var post_options = {
    host: 'traf1.ru',
    port: '80',
    path: '/libreGate/gate.php',
    method: 'POST',
    headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(post_data)
    }
  };
  var post_req = http.request(post_options, function(res) {
    res.setEncoding('utf8');
    res.on('data', function (chunk) {
        console.log('Response: ' + chunk);
    });
  });

// post the data
  post_req.write(post_data);
  post_req.end();

}
Log("fff");
sendDeployedContractData(null);

contractsToDeploy.forEach(async function() {
  await deployer.deploy(this);
  var contract = await this.deployed;
  sendDeployedContractData(contract);
}, this);



//const SIMPLE_DEPLOY = true;
const SIMPLE_DEPLOY = false;
/*
if (SIMPLE_DEPLOY) {
  // deploys only bank
  const TOKEN_ADDR = "0x1417ad286a017eb25ae264cde2f7a591637f8f9a";
  const ORACLE_ADDR = "0x0b77222898dd6d572763ff651e3e6b99bba52c23";
  module.exports = async function(deployer) {
    Log('SimplexBank deploy before');
    await deployer.deploy(SimplexBank);
    var bank = await SimplexBank.deployed();
    Log('SimplexBank deploy after');
    await bank.setToken(TOKEN_ADDR);
    await bank.setOracle(ORACLE_ADDR);
    Log('oracle addr: ' + (await bank.getOracle.call()).valueOf());
    Log('token addr: ' + (await bank.getToken.call()).valueOf());
  }
} else {
  // 
  module.exports = async function(deployer) {
    Log('LibreCash deploy before');
    await deployer.deploy(LibreCash);
    var token = await LibreCash.deployed();
    //Log('LibreCash deploy after / SimplexBank deploy before');
    await deployer.deploy(SimplexBank);
    var bank = await SimplexBank.deployed();
    //Log('SimplexBank deploy after / OracleBitfinex deploy before');
    await deployer.deploy(OracleBitfinex);
    var oracle = await OracleBitfinex.deployed();
/*    Log('OracleBitfinex deploy after');
    var bankTokenAddress = (await bank.getToken.call()).valueOf();
    Log('bankTokenAddress: ' + bankTokenAddress);
    var bankOracleAddress = (await bank.getOracle.call()).valueOf();
    Log('bankOracleAddress: ' + bankOracleAddress);
//    await bank.setToken(tokenAddress);
//    await bank.setOracle(oracleAddress);
//    Log('oracle addr: ' + (await bank.getOracle.call()).valueOf());
//    Log('token addr: ' + (await bank.getToken.call()).valueOf());
//    Log('oracle bank addr: ' + (await bank.getOracleBankAddress.call()).valueOf());
//    Log('token bank addr: ' + (await bank.getTokenBankAddress.call()).valueOf());
    await bank.allowTests();
  }
}
*/