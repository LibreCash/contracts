monitor = ['waitQuery', 'rate', 'bankAddress', 'updateTime', 'gasPrice', 'gasLimit'];

async function main() {
    contract = web3.eth.contract(JSON.parse(contractABI)).at(contractAddress); 
    web3.eth.defaultAccount = web3.eth.coinbase;
}

async function testSetGasPrice() {
    var price = parseInt(prompt("new gas price (GWei): ", "20"));
    var setGasPriceAddr = await contract.setGasPrice(price * 1e9);
    await web3.eth.getTransactionReceiptMined(setGasPriceAddr);
    logTransactionByReceipt(setGasPriceAddr);
}

async function testSetGasLimit() {
    var limit = parseInt(prompt("new gas limit: ", "100000"));
    var setGasLimitAddr = await contract.setGasLimit(limit);
    await web3.eth.getTransactionReceiptMined(setGasLimitAddr);
    logTransactionByReceipt(setGasLimitAddr);
}

main();