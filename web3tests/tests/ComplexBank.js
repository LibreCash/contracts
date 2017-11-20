monitor = ['getBuyOrdersCount', 'getSellOrdersCount', 'getToken', 'numEnabledOracles', 'numReadyOracles', 'getOracleCount',
           'buyFee', 'sellFee', 'cryptoFiatRate', 'cryptoFiatRateBuy', 'cryptoFiatRateSell',
           //'getBuyOrder(1)', 'getSellOrder(1)'
        ];

async function main() {
    contract = web3.eth.contract(JSON.parse(contractABI)).at(contractAddress); 
    web3.eth.defaultAccount = web3.eth.coinbase;
}

async function testFee() {  
    var setBuyFeeAddr = await contract.setBuyFee(500);
    var setBuyFeeMined = await web3.eth.getTransactionReceiptMined(setBuyFeeAddr);
    logTransactionByReceipt(setBuyFeeAddr);
}

async function testRequestUpdateRates() {
    var requestUpdateRatesAddr = await contract.requestUpdateRates({gas: 500000});
    var requestUpdateRatesMined = await web3.eth.getTransactionReceiptMined(requestUpdateRatesAddr);
    logTransactionByReceipt(requestUpdateRatesAddr);
}

async function testCalcRates() {
    var calcRatesAddr = await contract.calcRates({gas: 500000});
    var calcRatesMined = await web3.eth.getTransactionReceiptMined(calcRatesAddr);
    logTransactionByReceipt(calcRatesAddr);
}

main();