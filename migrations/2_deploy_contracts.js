var fs = require('fs');

rimraf("./build/contracts");

var contracts = ['token/LibreCash',
                'oracles/OracleBitfinex',
                'oracles/OracleBitstamp',
                'oracles/OracleWEX',
                //'BasicBank',
                'bank/complexBank'
              ];

var contractsToDeploy = {};
contracts.forEach(function(_contractPath) {
  let _contractName = _contractPath.replace(/^.*[\\\/]/, '');
  contractsToDeploy[_contractName] = artifacts.require("./" + _contractPath + ".sol");
});

module.exports = function(deployer) {
  contracts.forEach(function(_contractPath) {
    let artifact = artifacts.require("./" + _contractPath + ".sol");
    let _contractName = _contractPath.replace(/^.*[\\\/]/, '');
    deployer.deploy(artifact).then(function() {
      artifact.deployed().then(function(instance) {
        // в функции ниже ставим зависимости, она не для финального деплоя
        temporarySetDependencies(_contractName, instance);
        var contractABI = JSON.stringify(artifact._json.abi);
        var contractAddress = artifact.address;
        writeDeployedContractData(_contractPath, contractAddress, contractABI);
      });
    });
  }); // foreach
  finalizeDeploy();
};

var oracleAddresses = [];
var tokenAddress;
function temporarySetDependencies(contractName, instance) {
  if (contractName.substring(0, 6) == "Oracle") {
    oracleAddresses.push(instance.address);
  }
  if (contractName == "LibreCash") {
    tokenAddress = instance.address;
  }
  if (contractName == "complexBank") {
    oracleAddresses.forEach(function(oracleAddress) {
      instance.addOracle(oracleAddress);
    });
    instance.attachToken(tokenAddress);
    //instance.setRateLimits(10000, 40000); // 100$ to 400$ eth/usd
  }
}

function finalizeDeploy() {
  var directory = "web3tests/";
  var fileName = "listTestsAndContracts.js";
  var jsDataContracts = "var contracts = [{0}];\r\n";
  var listOfContracts = "";
  contracts.forEach(function(contractName) {
    listOfContracts += "'{0}', ".replace("{0}", contractName);
  });

  var jsDataTests = "var tests = [{0}];";
  var listOfTests = "";
  fs.readdirSync(directory + "tests/").forEach(_fileName => {
    listOfTests += "'{0}', ".replace("{0}", _fileName);
  })
  var stream = fs.createWriteStream(directory + fileName);
  stream.once('open', function(fd) {
    stream.write(jsDataContracts.replace("{0}", listOfContracts));
    stream.write(jsDataTests.replace("{0}", listOfTests));
    stream.end();
  });
}

function writeDeployedContractData(contractName, contractAddress, contractABI) {
  try {
    fs.unlinkSync("build/contracts/" + contractName + ".json");
  } catch (err) {
    console.log(err.message);
  }
  var directory = "web3tests/data/";
  var fileName = contractName + ".js";
  var stream = fs.createWriteStream(directory + fileName);
  stream.once('open', function(fd) {
    let contractData = {
      "contractName": contractName,
      "contractAddress": contractAddress,
      "contractABI": contractABI
    }
    stream.write("contractName = '{0}';\r\n".replace('{0}', contractData.contractName));
    stream.write("contractAddress = '{0}';\r\n".replace('{0}', contractData.contractAddress));
    stream.write("contractABI = '{0}';\r\n".replace('{0}', contractData.contractABI));
    stream.end();
  });
}

// удаление папки
function rimraf(dir_path) {
  if (fs.existsSync(dir_path)) {
      fs.readdirSync(dir_path).forEach(function(entry) {
          var entry_path = path.join(dir_path, entry);
          if (fs.lstatSync(entry_path).isDirectory()) {
              rimraf(entry_path);
          } else {
              fs.unlinkSync(entry_path);
          }
      });
      fs.rmdirSync(dir_path);
  }
}

