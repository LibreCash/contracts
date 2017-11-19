var fs = require('fs');
const path = require('path');

module.exports = async function(deployer, network) {
  var contracts = ['token/LibreCash','bank/ComplexBank'];

  if (network == "mainnet") {
    contracts = contracts.concat(
      ['oracles/OracleBitfinex',
       'oracles/OracleBitstamp',
        //'oracles/OracleWEX',
        //'oracles/OracleGDAX',
        //'oracles/OracleGemini',
        //'oracles/OracleKraken',
        //'oracles/OraclePoloniex'
       ]);
  } else {
    contracts = contracts.concat(
      ['oracles/mock/OracleMockLiza',
       'oracles/mock/OracleMockSasha',
       'oracles/mock/OracleMockKlara',
       //'oracles/mock/OracleMockRandom'
      ]);
  }

  var contractsToDeploy = {};
  contracts.forEach(function(_contractPath) {
    let _contractName = path.posix.basename(_contractPath);
    contractsToDeploy[_contractName] = artifacts.require("./" + _contractPath + ".sol");
  });

  await Promise.all(contracts.map(async function(_contractPath) {
    let artifact = artifacts.require("./" + _contractPath + ".sol");
    await deployer.deploy(artifact);
    let 
      instance = await artifact.deployed(),
      contractABI = JSON.stringify(artifact._json.abi),
      contractAddress = artifact.address;

      writeDeployedContractData(_contractPath, contractAddress, contractABI);
  })); // foreach
  await finalizeDeployDependencies(contractsToDeploy);
};

async function finalizeDeployDependencies(_contractsToDeploy) {
  var bank;
  // find the bank
  for (var _contractName in _contractsToDeploy) {
    if (search(_contractName,"bank")) {
      bank = _contractsToDeploy[_contractName];
      break;
    }
  }
  if (bank == null) {
    console.log("No bank contract found!");
    return;
  }

  for (var _contractName in _contractsToDeploy) {
    if (search(_contractName,"oracle")) {
      let 
        oracleInstance = await _contractsToDeploy[_contractName].deployed(),
        bankInstance = await bank.deployed();
        await bankInstance.addOracle(oracleInstance.address);
        await oracleInstance.setBank(bankInstance.address);
    }
    if (search(_contractName,"token") || search(_contractName,"cash")) {
      let 
        tokenInstance = await _contractsToDeploy[_contractName].deployed(),
        bankInstance = await bank.deployed();
        await bankInstance.attachToken(tokenInstance.address);
    }
  }
}

function search(string,substring) {
    return string.toLowerCase().indexOf(substring) != -1;
}

function writeDeployedContractData(contractPath, contractAddress, contractABI) {
  let 
      dir = "build/data/",
      contractName = path.posix.basename(contractPath),
      contractData = {
        contractName,
        contractAddress,
        contractABI
      };
  fs.writeFileSync(`${dir}/${contractName}.json`,JSON.stringify(contractData));    
}