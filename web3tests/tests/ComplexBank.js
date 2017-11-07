monitor = ['getBuyOrdersCount', 'getSellOrdersCount', 'getToken', 'numWaitingOracles', 'numEnabledOracles', 'numReadyOracles', 'getOracleCount',
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
    var requestUpdateRatesAddr = await contract.requestUpdateRates({gas: 500000});
    var requestUpdateRatesMined = await web3.eth.getTransactionReceiptMined(requestUpdateRatesAddr);
    console.log(web3.eth.getTransactionReceipt(requestUpdateRatesAddr));
}

async function testCalcRates() {
    var calcRatesAddr = await contract.calcRates({gas: 500000});
    var calcRatesMined = await web3.eth.getTransactionReceiptMined(calcRatesAddr);
    console.log(web3.eth.getTransactionReceipt(calcRatesAddr));
}

main();