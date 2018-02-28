const 
  fs = require('fs'),
  path = require('path');

module.exports = async function(deployer, network) {
  var 
    bank = artifacts.require('./ComplexBank.sol'),
    association = artifacts.require('./Association.sol'),
    liberty = artifacts.require('./LibertyToken.sol'),
    token = artifacts.require('./LibreCash.sol');

  let
    сontractsList = {
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
    contracts = (network == "mainnet") ?  сontractsList.mainnet : сontractsList.local;

  var
    contractsToDeploy = {};

  oracles = [];
  contracts.forEach(function(contractPath) {
    let name = path.posix.basename(contractPath),
        contract = artifacts.require(`./${contractPath}.sol`);
    contractsToDeploy[name] = contract;
    oracles.push(contract);
  });
  contractsToDeploy["ComplexBank"] = bank;
  contractsToDeploy["Association"] = association;
  contractsToDeploy["LibreCash"] = token;
  contractsToDeploy["LibertyToken"] = liberty;

  await Promise.all(oracles.map((oracle) => deployer.deploy(oracle)));

  let oraclesAddress = await Promise.all(oracles.map( 
    async (oracle) => (await oracle.deployed()).address
  ));

  await deployer.deploy(token);
  await deployer.deploy(liberty);
  await deployer.deploy(bank, token.address, oraclesAddress);
  await deployer.deploy(
    association,
    liberty.address,
    bank.address,
    token.address,
    /* minimumSharesToPassAVote: */ 1,
    /* minMinutesForDebate: */ 1
  );

  console.log(`Start applying contracts deps`);
  for (var i in oracles) {
    let oracle = await oracles[i].deployed();
    await oracle.setBank(bank.address);
    console.log(`Oracle ${oracle.address} attached to bank: ${bank.address}`);
  }

  for(var name in contractsToDeploy) {
    await writeContractData(name, contractsToDeploy[name]);
  }
  console.log(`Finish applying contracts deps`);
};

async function writeContractData(name, artifact) {
  let 
    instance = await artifact.deployed(),
    contractName = path.posix.basename(name),
    directory = "build/data/";

    createDir(directory);
    fs.writeFileSync(`${directory}${contractName}.js`,
        `contractName: ${contractName}\ncontractABI: ${JSON.stringify(artifact._json.abi)}\ncontractAddress: ${artifact.address}`);
}

function createDir(dirname) {
  if (!fs.existsSync(dirname)) {
     fs.mkdirSync(dirname);
  }
}