const 
  fs = require('fs'),
  path = require('path');

module.exports = async function(deployer, network) {
    let
        contractsList = {
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
            ],
            bounty:[
                'bounty/BountyOracle1',
                'bounty/BountyOracle2',
                'bounty/BountyOracle3'
            ]
        },
        deployBank = false,
        deployDAO = false, // is actual when deployBank only
        deployDeposit = false,
        deployFaucet = false,
        deployLoans = false,
        deployAsBounty = true,
        
        appendContract = deployAsBounty ? contractsList.bounty :
                    ((network == "mainnet" || network == "testnet") ? contractsList.mainnet : contractsList.local),
        oracles = appendContract.map((oracle) => {
            name = path.posix.basename(oracle);
            return artifacts.require(`./${name}.sol`);
        }),

        cash = artifacts.require('./LibreCash.sol'),
        liberty = artifacts.require('./LibertyToken.sol'),
        association = artifacts.require('./Association.sol'),
        exchanger = artifacts.require(`./Complex${deployBank ? 'Bank' : 'Exchanger'}.sol`),
        bounty = artifacts.require(`./Complex${deployBank ? 'Bank' : 'Exchanger'}Bounty.sol`),
        bountyBank = artifacts.require(`./ComplexBankBounty.sol`),
        bountyExchanger = artifacts.require(`./ComplexExchangerBounty.sol`),
        deposit = artifacts.require('./Deposit.sol'),
        loans = deployLoans ? artifacts.require(`./Loans.sol`) : null,
        faucet = artifacts.require('./LBRSFaucet.sol');
  
        config = {
            buyFee: 250,
            sellFee: 250,
            deadline: getTimestamp(+5),
            withdrawWallet: web3.eth.coinbase,
        };
    // end let block

    await Promise.all(oracles.map((oracle) => deployer.deploy(oracle)))
    let _oracles = await Promise.all(oracles.map((oracle) => oracle.deployed()))

    let oraclesAddress = oracles.map((oracle) => oracle.address);
    console.log("Contract configuration");
    console.log(config);

    if (!deployAsBounty) {
        await deployer.deploy(cash);
        let _cash = await cash.deployed()
    
        if (deployBank && deployDAO) {
            await deployer.deploy(liberty);
        }

        let args = [
            exchanger,
            /*Constructor params*/
            cash.address, // Token address
            config.buyFee, // Buy Fee
            config.sellFee, // Sell Fee,
            oraclesAddress,// oracles (array of address)
        ];

        if (!deployBank) {
            args = args.concat([config.deadline, config.withdrawWallet]);
        }

        await deployer.deploy(...args);
        let _exchanger = deployAsBounty ? null : await exchanger.deployed();
        await Promise.all(_oracles.map((oracle) => oracle.setBank(exchanger.address)));
        if (!deployBank)
            await _cash.mint.sendTransaction(exchanger.address, 100 * 10 ** 18);

        if (deployBank && deployDAO) {
            await deployer.deploy(
                association,
                /* Constructor params */
                liberty.address,
                exchanger.address,
                cash.address,
                /* minimumSharesToPassAVote: */ 1,
                /* minSecondsForDebate: */ 60
            );
        }

        // mint tokens to me for tests :)
        _cash.mint.sendTransaction(web3.eth.coinbase, 1000 * 10 ** 18);

        if (deployFaucet && deployBank && deployDAO) {
            await deployer.deploy(
                faucet,
                /* Constructor params */
                liberty.address
            );
            await faucet.deployed();
            let _liberty = await liberty.deployed();
            await _liberty.transfer.sendTransaction(faucet.address, 1000000 * 10 ** 18);
        }

        if (deployDeposit) {
            await deployer.deploy(deposit, cash.address);
            await _cash.mint.sendTransaction(deposit.address, 10000 * 10 ** 18),
            await _cash.approve.sendTransaction(deposit.address, 10000 * 10 ** 18)
        }

        // transfer ownership to the bank (not exchanger) contract
        if (deployBank) {
            await _cash.transferOwnership(exchanger.address);
            await _exchanger.claimOwnership()
        }

        if (deployBank && deployDAO)
            await _exchanger.transferOwnership(association.address)

        if (deployLoans)
        await deployer.deploy(loans, cash.address, exchanger.address);

        writeContractData(cash);
        writeContractData(exchanger);
        if (deployBank && deployDAO) {
            writeContractData(liberty);
            writeContractData(association);
        }
        if (deployFaucet) {
            writeContractData(faucet);
        }
        if (deployDeposit) {
            writeContractData(deposit);
        }
        if (deployLoans) {
            writeContractData(loans);
        }
    } else { // if (deployAsBounty)
        await deployer.deploy(bountyBank, getTimestamp(+5), oraclesAddress);
        await deployer.deploy(bountyExchanger, getTimestamp(+5), oraclesAddress);
        writeContractData(bountyBank);
        writeContractData(bountyExchanger);
    }
    
    oracles.forEach((oracle) => {
        writeContractData(oracle);
    });

    let mistContracts = deployAsBounty ?
        [
            bountyBank,
            bountyExchanger
        ] :
        [
            exchanger,
            cash,
            (deployBank && deployDAO) ? liberty : null,
            (deployBank && deployDAO) ? association : null,
            deployDeposit ? deposit : null,
            deployLoans ? loans : null,
            deployFaucet ? faucet : null            
        ];

    createMistLoader(
        mistContracts.concat(oracles),
        !deployAsBounty ? cash : null,
        (deployBank && deployDAO && !deployAsBounty) ? liberty : null
    )

    console.log("END DEPLOY");
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
    fs.writeFileSync(`${directory}${artifact.contractName}.js`, data);
}

function createMistLoader(contracts, cash, liberty) {
    let loader = `${__dirname}/../build/data/loader.js`;
    var data = `        // paste the script to mist developer console to autoimport all deployed contracts and tokens
        CustomContracts.find().fetch().map((m) => {if (m.name.indexOf('_') == 0) CustomContracts.remove(m._id)});
        Tokens.find().fetch().map((m) => {if (m.name.indexOf('_') == 0) Tokens.remove(m._id)});`;
    for (let i = 0; i < contracts.length; i++) {
        if (contracts[i] == null) continue;
        data += `
        CustomContracts.insert({
            address: "${contracts[i].address}",
            name: "_${contracts[i].contractName}",
            jsonInterface: ${JSON.stringify(contracts[i]._json.abi)}
        });`;
    }
    if (cash != null) {
        data += `
        Tokens.insert({
            address: "${cash.address}",
            decimals: 18,
            name: "_LibreCash",
            symbol: "_Libre"
        });`
    }
    if (liberty != null) {
        data += `
        Tokens.insert({
            address: "${liberty.address}",
            decimals: 18,
            name: "_Liberty",
            symbol: "_LBRS"
        });`
    }
    fs.writeFileSync(loader, data);
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