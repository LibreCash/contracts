monitor = ['getBuyOrdersCount', 'getSellOrdersCount', 'getToken', 'numEnabledOracles', 'numReadyOracles', 'getOracleCount',
           'buyFee', 'sellFee', 'cryptoFiatRate', 'cryptoFiatRateBuy', 'cryptoFiatRateSell',
           //'getBuyOrder(1)', 'getSellOrder(1)'
        ];

async function main() {
    contract = web3.eth.contract(JSON.parse(contractABI)).at(contractAddress); 
    web3.eth.defaultAccount = web3.eth.coinbase;
}

async function testFee() {
    console.log("buyFee: " + contract.buyFee().toString(10));
    console.log("sellFee: " + contract.sellFee().toString(10));
    console.log("cryptoFiatRateBuy: " + contract.cryptoFiatRateBuy().toString(10));
    console.log("cryptoFiatRateSell: " + contract.cryptoFiatRateSell().toString(10));
    var setFeesAddr = await contract.setFees(500, 500);
    var setFeesMined = await web3.eth.getTransactionReceiptMined(setFeesAddr);
    logTransactionByReceipt(setFeesAddr);
    console.log("buyFee: " + contract.buyFee().toString(10));
    console.log("sellFee: " + contract.sellFee().toString(10));
    console.log("cryptoFiatRateBuy: " + contract.cryptoFiatRateBuy().toString(10));
    console.log("cryptoFiatRateSell: " + contract.cryptoFiatRateSell().toString(10));
    var setFeesAddr = await contract.setFees(0, 0);
    var setFeesMined = await web3.eth.getTransactionReceiptMined(setFeesAddr);
    logTransactionByReceipt(setFeesAddr);
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