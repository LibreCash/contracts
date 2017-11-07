monitor = ['getBuyOrdersCount', 'getSellOrdersCount', 'getToken', 'numWaitingOracles', 'numEnabledOracles', 'getOracleCount',
           'buyFee', 'sellFee', 'cryptoFiatRate', 'cryptoFiatRateBuy', 'cryptoFiatRateSell'
        ];

async function main() {
    contract = web3.eth.contract(JSON.parse(contractABI)).at(contractAddress); 
    web3.eth.defaultAccount = web3.eth.coinbase;
}

async function testFee() {  
    var setBuyFeeAddr = await contract.setBuyFee(500);
    var setBuyFeeMined = await web3.eth.getTransactionReceiptMined(setBuyFeeAddr);
    console.log(web3.eth.getTransactionReceipt(setBuyFeeAddr));
}

async function testRequestUpdateRates() {
    var requestUpdateRatesAddr = await contract.requestUpdateRates({gas: 200000});
    var requestUpdateRatesMined = await web3.eth.getTransactionReceiptMined(requestUpdateRatesAddr);
    console.log(web3.eth.getTransactionReceipt(requestUpdateRatesAddr));
}

main();