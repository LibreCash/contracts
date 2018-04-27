const 
    fs = require('fs'),
    path = require('path'),
    profiles = require("./profiles.js"),
    default_config = {
        buyFee: 250,
        sellFee: 250,
        deadline: getTimestamp(+5),
        withdrawWallet: web3.eth.coinbase,
    };

module.exports = async function(deployer, network) {
    const deploy = require(`./${network}.js`);

    let contracts = profiles[network].contracts.map((name) => artifacts.require(`./${name}.sol`));
    let config = profiles[network].config ? profiles[network].config : default_config;

    await deploy(deployer, contracts, config);

    contracts.forEach(contract => writeContractData(contract))
    createMistLoader(contracts);

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

        if (['LibreCash','LibertyToken'].includes(contracts[i].contractName))
            data += `
            Tokens.insert({
                address: "${cash.address}",
                decimals: 18,
                name: "_${contracts[i].contractName}",
                symbol: "_${contracts[i].contractName == 'LibreCash' ? 'Libre' : 'LBRS'}"
            });`
        else
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