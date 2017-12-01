monitor = ['waitQuery', 'rate', 'bankAddress', 'updateTime'];

async function main() {
    contract = web3.eth.contract(JSON.parse(contractABI)).at(contractAddress); 
    web3.eth.defaultAccount = web3.eth.coinbase;
}

main();