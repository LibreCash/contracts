var fs = require('fs');

rimraf("build/contracts");

let testnetLocal = true;

if (testnetLocal) {
  var contracts = ['LocalRPCBank'];

  var contractsToDeploy = {};
  contracts.forEach(function(name) {
    contractsToDeploy[name] = artifacts.require("./" + name + ".sol");
  });

  module.exports = function(deployer) {
    contracts.forEach(function(contractName) {
      let artifact = artifacts.require("./" + contractName + ".sol");

      deployer.deploy(artifact).then(function() {
        artifact.deployed().then(function(instance) {

        });
      });
    });
  };
}
// ************************************************************************************************** //
else {
  var contracts = ['LibreCash',
                 'OracleBitfinex',
                 'OracleBitstamp',
                 //'OracleGDAX',
                 'OracleGemini',
                 'OracleKraken',
                 'OracleWEX',
                 'BasicBank'
                ];

  var contractsToDeploy = {};
  contracts.forEach(function(name) {
    contractsToDeploy[name] = artifacts.require("./" + name + ".sol");
  });

  module.exports = function(deployer) {
    contracts.forEach(function(contractName) {
      let artifact = artifacts.require("./" + contractName + ".sol");

      deployer.deploy(artifact).then(function() {
        artifact.deployed().then(function(instance) {
          // в функции ниже ставим зависимости, она не для финального деплоя
          temporarySetDependencies(contractName, instance);
          var contractABI = JSON.stringify(artifact._json.abi);
          var contractAddress = artifact.address;
          writeDeployedContractData(contractName, contractAddress, contractABI);
        });
      });
    });
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
    if (contractName == "BasicBank") {
      oracleAddresses.forEach(function(oracleAddress) {
        instance.addOracle(oracleAddress);
      });
      instance.attachToken(tokenAddress);
      //instance.addOracle('0x5b2e8ab98dcc4cb8ed7c485ed05ae81c7e727279');
      //instance.addOracle('0xcf4fe4f0bbc839ad2d5d8be00989fdf827f931e0');
      //instance.addOracle('0x00c0ddec392e7c29dd24b7aa71bf0f1b2ac7f4b6');
      //instance.attachToken('0x8BeAeee5A14469FAF17316DF6419936014daC870');
      instance.setRateLimits(10000, 40000); // 100$ to 400$ eth/usd
    }
  }

  function writeDeployedContractData(contractName, contractAddress, contractABI) {
    try {
      fs.unlinkSync("build/contracts/" + contractName + ".json");
    } catch (err) {
      console.log(err.message);
    }
    var directory = "build/data/";
    var fileName = contractName + ".txt";
    var stream = fs.createWriteStream(directory + fileName);
    stream.once('open', function(fd) {
      stream.write(contractName + "\n" + 
                  contractAddress + "\n\n" +
                  contractABI + "\n");
      stream.end();
    });
  }
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

