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
      deadline:getTimestamp(+1),
      withdrawWallet:web3.eth.coinbase,
  };

  deployer.deploy(cash)
    .then(() => Promise.all(oracles.map((oracle) => deployer.deploy(oracle))))
    .then(() => {
        oraclePromise = oracles.map((oracle) => oracle.deployed());
        oraclePromise.push(cash.deployed());
        return Promise.all(oraclePromise);
    })
    .then((contracts) => {
        let 
          cashContract = contracts.pop(),
          oraclesAddress = contracts.map((oracle) => oracle.address);
        
          console.log("Contract configuration");
          console.log(config);

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
    .then(() => {
        oraclePromise = oracles.map((oracle) => oracle.deployed());
        oraclePromise.push(exchanger.deployed());
        return Promise.all(oraclePromise);
    })
    .then((contracts) => {
        exch = contracts.pop();
        return Promise.all(contracts.map((oracle) => oracle.setBank(exch.address)));
    })
    .then(() => console.log("END DEPLOY"));
};

function getTimestamp (diffDays) {
  const msInDay = 86400000;
  return Math.round( (Date.now() + diffDays * msInDay) / 1000);
}