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
    oracles = appendContract.map( (oracle) => {
        name = path.posix.basename(oracle);
        return artifacts.require(`./${name}.sol`);
    });

  cash = artifacts.require('./LibreCash.sol');
  exchanger = artifacts.require(`./ComplexExchanger.sol`);
  
  config = {
      buyFee:250,
      sellFee:250,
      deadline:getTimestamp(2018,02,07),
      withdrawWallet:web3.eth.coinbase,
  };

  deployer.deploy(cash)
    .then( () => {return Promise.all(oracles.map( (oracle) => {return deployer.deploy(oracle);}))})
    .then( () => {
        oraclePromise = oracles.map( (oracle) => {return oracle.deployed();});
        oraclePromise.push(cash.deployed());
        return Promise.all(oraclePromise)
    })
    .then( (contracts) => {
        cashContract = contracts.pop();
        let oraclesAddress = contracts.map((oracle) => {return oracle.address});
        return deployer.deploy(
          exchanger,
          /*Constructor params*/
          cashContract.address, // Token address
          config.buyFee, // Buy Fee
          config.sellFee, // Sell Fee,
          oraclesAddress,// oracles (array of address)
          config.deadline, // deadline,
          config.withdrawWallet // withdraw wallet
        );
    })
    .then( () => {
        oraclePromise = oracles.map( (oracle) => {return oracle.deployed();});
        oraclePromise.push(exchanger.deployed());
        return Promise.all(oraclePromise);
    })
    .then( (contracts) => {
        exch = contracts.pop();
        return Promise.all(contracts.map( (oracle) => {return oracle.setBank(exch.address);}));})
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