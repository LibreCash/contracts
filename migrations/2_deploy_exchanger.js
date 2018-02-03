const 
  fs = require('fs'),
  path = require('path');

module.exports = async function(deployer, network) {
  let
    сontractsList = {
      base: ['token/LibreCash'],
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
      
    var contractsToDeploy = {};

  contracts.forEach(function(contractPath) {
    let name = path.posix.basename(contractPath);
    contractsToDeploy[name] = artifacts.require(`./${contractPath}.sol`);
  });

  await Promise.all(contracts.map((data)=>deployContract(deployer,data)));
  await applyDeps(contractsToDeploy,deployer);
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

async function applyDeps(contracts,deployer) {
  console.log(`Strart applying contracts deps`);
  let 
     // TODO:Refactor it
     exchangerArtifact = artifacts.require(`./ComplexExchanger.sol`);
  
  var oracles = [];

  for (var name in contracts) {
    if (search(name, "oracle")) {
      var 
        oracle = await contracts[name].deployed();
        console.log(oracle.address);
        oracles.push(oracle);
        console.log(oracles.length);
    }

    if (search(name, "token") || search(name, "cash")) {
        token = await contracts[name].deployed();
        console.log(token.address);
    }
  }

    oraclesAdreses = oracles.map((oracle)=>oracle.address);
    
    console.log (
      //Constructor params
      token.address, // Token address
      0, // Buy Fee
      0, // Sell Fee,
      oraclesAdreses,// oracles (array of address)
      0, // deadline,
      web3.eth.coinbase // withdraw wallet
    );

    // Deploy contract
    await deployer.deploy(
      exchangerArtifact,
      /*Constructor params*/
      token.address, // Token address
      25, // Buy Fee
      25, // Sell Fee,
      oraclesAdreses,// oracles (array of address)
      1000, // deadline,
      web3.eth.coinbase // withdraw wallet
    );

    let exchanger = await exchangerArtifact.deployed();
    

    oracles.forEach(async (oracle)=>{
      await setBankOracle(exchanger,oracle)
    });

  console.log(`Finish applying contracts deps`);
}

function search(string,substring) {
    return string.toLowerCase().indexOf(substring) != -1;
}


async function setBankOracle(exchanger,oracle){
  await oracle.setBank(exchanger.address); 
  console.log(`Oracle ${oracle.address} attached to: ${exchanger.address}`);
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

var getTimestamp = function(year,month,day) {
  return Math.round(new Date(year,month,day) / 1000);
}