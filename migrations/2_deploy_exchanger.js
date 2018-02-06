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
    exchangerConfig = {
      buyFee:0,
      sellFee:0,
      deadline:getTimestamp(2018,02,07),
      withdrawWallet:web3.eth.coinbase,
      token:web3.eth.coinbase, // Sets later after LibreCash deployment
      oracles:[] 
    };

    //appendContract = (network == "mainnet") ?  сontractsList.mainnet : сontractsList.local;
    //contracts = сontractsList.base.concat(appendContract);
      contracts = [];
    //var contractsToDeploy = {};

  //contracts.forEach(function(contractPath) {
    //let name = path.posix.basename(contractPath);
    //contractsToDeploy[name] = artifacts.require(`./${contractPath}.sol`);
  //});

  //await Promise.all(contracts.map((data)=>deployContract(deployer,data)));
  config = exchangerConfig;

  OracleMockLiza = artifacts.require(`./OracleMockLiza.sol`);
  OracleMockSasha = artifacts.require(`./OracleMockSasha.sol`);
  OracleMockKlara = artifacts.require(`./OracleMockKlara.sol`);
  exchangerArtifact = artifacts.require(`./ComplexExchanger.sol`);
  deployer.deploy(OracleMockLiza)
    .then( () => {return deployer.deploy(OracleMockSasha);})
    .then( () => {return deployer.deploy(OracleMockKlara);})
    .then( () => {return OracleMockLiza.deployed()})
    .then( (liza) => {contracts.push(liza.address);return OracleMockSasha.deployed()})
    .then( (sasha) => {contracts.push(sasha.address);return OracleMockKlara.deployed()})
    .then( (klara) => {
        contracts.push(klara.address);
        console.log(contracts);
        return deployer.deploy(
      exchangerArtifact,
      /*Constructor params*/
      config.token, // Token address
      config.buyFee, // Buy Fee
      config.sellFee, // Sell Fee,
      contracts,// oracles (array of address)
      config.deadline, // deadline,
      config.withdrawWallet // withdraw wallet
    );
    })
    .then( () => console.log("END DEPLOY"));
  
  //await applyDeps(contractsToDeploy,deployer,exchangerConfig);
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

async function applyDeps(contracts,deployer,config) {
  console.log(`Strart applying contracts deps`);
  let 
     // TODO:Refactor it
     exchangerArtifact = artifacts.require(`./ComplexExchanger.sol`);
  var oracles = [];
  
  for (var name in contracts) {
    if (search(name, "oracle")) {
      var 
        oracle = await contracts[name].deployed();
        oracles.push(oracle);
    }

    if (search(name, "token") || search(name, "cash")) {
      config.token = (await contracts[name].deployed()).address;
    }
  }

    config.oracles = oracles.map((oracle)=>oracle.address);

    
    console.log(`Exchanger deploy parameters:
    Token (LibreCash) address: ${config.token},
    Buy fee:${config.buyFee}
    Sell fee:${config.sellFee}
    Oracles:${config.oracles}`);

    // Deploy contract
    await deployer.deploy(
      exchangerArtifact,
      /*Constructor params*/
      config.token, // Token address
      config.buyFee, // Buy Fee
      config.sellFee, // Sell Fee,
      config.oracles,// oracles (array of address)
      config.deadline, // deadline,
      config.withdrawWallet // withdraw wallet
    );

    let exchanger = await exchangerArtifact.deployed();
    

    oracles.forEach(async (oracle)=>{
      await setBankOracle(exchanger,oracle)
    });

    writeContractData({
        contractName: "ComplexExchanger",
        contractABI: exchangerArtifact._json.abi,
        contractAddress: exchangerArtifact.address,
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