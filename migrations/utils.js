const
    fs = require('fs');

module.exports = {

    getTimestamp: (diffDays) => {
        const msInDay = 86400000;
        return Math.round((Date.now() + diffDays * msInDay) / 1000);
    },

    createDir: (dirname) => {
        if (!fs.existsSync(dirname)) {
            fs.mkdirSync(dirname);
        }
    },

    createMistLoader: (contracts) => {
        let loader = `${__dirname}/../build/data/loader.js`;
        var data = `        // paste the script to mist developer console to autoimport all deployed contracts and tokens
        CustomContracts.find().fetch().map((m) => {if (m.name.indexOf('_') == 0) CustomContracts.remove(m._id)});
        Tokens.find().fetch().map((m) => {if (m.name.indexOf('_') == 0) Tokens.remove(m._id)});`;
        for (let i = 0; i < contracts.length; i++) {
            if (contracts[i] == null) continue;

            if (['LibreCash', 'LibertyToken'].includes(contracts[i].contractName)) {
                data += `
            Tokens.insert({
                address: "${contracts[i].address}",
                decimals: 18,
                name: "_${contracts[i].contractName}",
                symbol: "_${contracts[i].contractName === 'LibreCash' ? 'Libre' : 'LBRS'}"
            });`;
            }

            data += `
            CustomContracts.insert({
                address: "${contracts[i].address}",
                name: "_${contracts[i].contractName}",
                jsonInterface: ${JSON.stringify(contracts[i]._json.abi)}
            });`;
        }
        console.log("console-log-2")
        fs.writeFileSync(loader, data);
    },

    writeContractData: (artifact) => {
        let directory = `${__dirname}/../build/data/`,
            mew_abi = {};

        artifact._json.abi.forEach((item) => { mew_abi[item.name] = item; });
        let data = `name: "${artifact.contractName}",\n` +
        `address: "${artifact.address}",\n` +
        `abi: '${JSON.stringify(artifact._json.abi)}',\n` +
        `abiRefactored: '${JSON.stringify(mew_abi)}'`;

        createDir(directory);
        fs.writeFileSync(`${directory}${artifact.contractName}.js`, data);
    },

};
