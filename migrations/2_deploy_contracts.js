const 
  fs = require('fs'),
  path = require('path');

module.exports = async function(deployer, network) {
  let
    сontractsList = {
      base: ['token/LibreCash', 'ComplexBank','ComplexExchanger'],
      mainnet:[
        'oracles/OracleBitfinex',
        'oracles/OracleBitstamp',
        'oracles/OracleWEX',
        'oracles/OracleGDAX',
        'oracles/OracleGemini',
        'oracles/OracleKraken',
      ],
      local:[
        'oracles/mock/OracleMockLiza',
        'oracles/mock/OracleMockSasha',
        'oracles/mock/OracleMockKlara',
        'oracles/OracleMockTest'
     ]
    },
    appendContract = (network == "mainnet") ?  сontractsList.mainnet : сontractsList.local;
    contracts = сontractsList.base.concat(appendContract);
      
    var  contractsToDeploy = {};

  contracts.forEach(function(contractPath) {
    let name = path.posix.basename(contractPath);
    contractsToDeploy[name] = artifacts.require(`./${contractPath}.sol`);
  });

  await Promise.all(contracts.map((data)=>deployContract(deployer,data)));
  await applyDeps(contractsToDeploy);
};


async function deployContract(deployer,contractPath) {
    let 
      artifact = artifacts.require(`./${contractPath}.sol`);

    await deployer.deploy(artifact);

    let 
      instance = await artifact.deployed(),
      contractData = {
        contractName: path.posix.basename(contractPath),
        contractABI: artifact._json.abi,
        contractAddress: artifact.address,
      };

    writeContractData(contractData);
}

async function applyDeps(contracts) {
  console.log(`Strart applying contracts deps`);
  let 
    bankContract = contracts["ComplexBank"],
    exchangerContract = contracts["ComplexExchanger"];
 
  if (bankContract == null) {
    console.log("No bank contract found!");
    return;
  }

  let 
    bank = await bankContract.deployed(),
    exchanger = await exchangerContract.deployed();

  for (var name in contracts) {
    if (search(name, "oracle")) {
      var 
        oracle = await contracts[name].deployed();
        await addOracle(bank,oracle);
        await addOracle(exchanger,oracle);
    }

    if (search(name, "token") || search(name, "cash")) {
        token = await contracts[name].deployed(),
        await attachToken(bank,token);
        await attachToken(exchanger,token);
    }
  }
  console.log(`Finish applying contracts deps`);
}

function search(string,substring) {
    return string.toLowerCase().indexOf(substring) != -1;
}

async function attachToken(bank,token){
  await bank.attachToken(token.address);
  await token.transferOwnership(bank.address);
  console.log(`Token ${token.address} attached to bank: ${bank.address}`);
}

async function addOracle(bank,oracle){
  await bank.addOracle(oracle.address);
  await oracle.setBank(bank.address); 
  console.log(`Oracle ${oracle.address} attached to bank: ${bank.address}`);
}

function writeContractData(data) {
  let 
    directory = "build/data/";
    createDir(directory);
    fs.writeFileSync(`${directory}${data.contractName}.js`,JSON.stringify(data));
}

function createDir(dirname) {
  if (!fs.existsSync(dirname)) {
     fs.mkdirSync(dirname);
  }
}