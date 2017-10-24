var fs = require('fs');

var contracts = ['LibreCash',
                 'BasicBank',
                 'OracleBitfinex',
                 'OracleBitstamp',
                 'OracleGDAX',
                 'OracleGemini',
                 'OracleKraken',
                 'OracleWEX'
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
        temporarySetDependencies(contractName);
        var contractABI = JSON.stringify(artifact._json.abi);
        var contractAddress = artifact.address;
        writeDeployedContractData(contractName, contractAddress, contractABI);
      });
    });
  });
};

function temporarySetDependencies(contractName) {
  if (contractName == "BasicBank") {
    instance.addOracle('0x5b2e8ab98dcc4cb8ed7c485ed05ae81c7e727279');
    instance.addOracle('0xcf4fe4f0bbc839ad2d5d8be00989fdf827f931e0');
    instance.addOracle('0x00c0ddec392e7c29dd24b7aa71bf0f1b2ac7f4b6');
    instance.attachToken('0x8BeAeee5A14469FAF17316DF6419936014daC870');
  }
}

function writeDeployedContractData(contractName, contractAddress, contractABI) {
  fs.unlink("build/contracts/" + contractName + ".json", function(err) {
    if(err) {
      console.log(err);
    }
  });
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