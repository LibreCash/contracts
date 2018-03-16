const 
  fs = require('fs'),
  path = require('path');

module.exports = function(deployer, network) {
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
        deployBank = false,
        deployDAO = false, // is actual when deployBank only

        appendContract = (network == "mainnet" || network == "testnet") ? сontractsList.mainnet : сontractsList.local,
        oracles = appendContract.map((oracle) => {
            name = path.posix.basename(oracle);
            return artifacts.require(`./${name}.sol`);
        }),

        cash = artifacts.require('./LibreCash.sol'),
        liberty = artifacts.require('./LibertyToken.sol'),
        association = artifacts.require('./Association.sol'),
        exchanger = artifacts.require(`./Complex${deployBank ? 'Bank' : 'Exchanger'}.sol`),
  
        config = {
            buyFee: 250,
            sellFee: 250,
            deadline: getTimestamp(+5),
            withdrawWallet: web3.eth.coinbase,
        };
    // end let block


    deployer.deploy(cash)
    .then(() => {
        if (deployBank && deployDAO) return deployer.deploy(liberty);
    })
    .then(() => Promise.all(oracles.map((oracle) => deployer.deploy(oracle))))
    .then(() => {
        let oraclesAddress = oracles.map((oracle) => oracle.address);
        
        console.log("Contract configuration");
        console.log(config);

        let args = [
            exchanger,
            /*Constructor params*/
            cash.address, // Token address
            config.buyFee, // Buy Fee
            config.sellFee, // Sell Fee,
            oraclesAddress,// oracles (array of address)
        ];

        if (!deployBank)
            args = args.concat([config.deadline, config.withdrawWallet]);

        return deployer.deploy(...args);
    })
    .then(() => Promise.all(oracles.map((oracle) => oracle.deployed())))
    .then((contracts) => Promise.all(contracts.map((oracle) => oracle.setBank(exchanger.address))))
    .then(() => cash.deployed())
    .then((_cash) => {
        if (deployBank)
            return _cash.transferOwnership(exchanger.address)
    })
    .then(() => exchanger.deployed())
    .then((_exchanger) => {
        if (deployBank)
            return _exchanger.claimOwnership()
    })
    .then(() => {
        if (deployBank && deployDAO) {
            return deployer.deploy(
                association,
                /* Constructor params */
                liberty.address,
                exchanger.address,
                cash.address,
                /* minimumSharesToPassAVote: */ 1,
                /* minMinutesForDebate: */ 1
            );
        }
    })
    .then(() => {
        if (deployBank && deployDAO) {
            return exchanger.deployed();
        }
    })
    .then((_exchanger) => {
        if (deployBank && deployDAO) {
            return _exchanger.transferOwnership(association.address)
        }
    })
    .then(() => {
        return cash.deployed()
    })
    .then((_cash) =>{
        if (!deployBank) {
            return _cash.mint.sendTransaction(exchanger.address, 100 * 10 ** 18)
        }
    })
    .then(() => {
        writeContractData(cash);
        if (deployBank && deployDAO) {
            writeContractData(liberty);
            writeContractData(association);
        }
        writeContractData(exchanger);
        oracles.forEach((oracle) => {
            writeContractData(oracle);
        });
    })
    .then(() => console.log("END DEPLOY"));
}; // end module.exports

function writeContractData(artifact) {
    let directory = `${__dirname}/../build/data/`,
        mew_abi = {};

    artifact._json.abi.forEach((item) => mew_abi[item.name] = item);
    let data =  `name: "${artifact.contractName}",\n` +
                `address: "${artifact.address}",\n` +
                `abi: '${JSON.stringify(artifact._json.abi)}',\n` +
                `abiRefactored: '${JSON.stringify(mew_abi)}'`;

    createDir(directory);
    fs.writeFileSync(`${directory}${artifact.contractName}.js`,data);
}

function createDir(dirname) {
    if (!fs.existsSync(dirname)) {
       fs.mkdirSync(dirname);
    }
};

function getTimestamp (diffDays) {
  const msInDay = 86400000;
  return Math.round( (Date.now() + diffDays * msInDay) / 1000);
}