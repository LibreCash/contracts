monitor = ['numWaitingOracles', 'sellFee', 'buyFee'];

async function main() {
    contract = web3.eth.contract(JSON.parse(contractABI)).at(contractAddress); 
    web3.eth.defaultAccount = web3.eth.coinbase;
}

async function testFee() {  
    var buyFee = await contract.buyFee.call();
    console.log(buyFee.toNumber());
    var setBuyFeeTXAddr = await contract.setBuyFee(500);
    var setBuyFeeTXMined = await web3.eth.getTransactionReceiptMined(setBuyFeeTXAddr);
    console.log(web3.eth.getTransactionReceipt(setBuyFeeTXAddr));
    var buyFee = await contract.buyFee.call();
    console.log(buyFee.toNumber());
}

main();