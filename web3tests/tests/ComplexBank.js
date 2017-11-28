monitor = ['getBuyOrdersCount', 'getSellOrdersCount', 'numEnabledOracles', 'numReadyOracles', 'countOracles',
           'buyFee', 'sellFee', 'cryptoFiatRate', 'cryptoFiatRateBuy', 'cryptoFiatRateSell',
           'relevancePeriod', 'timeUpdateRequest', 'timeSinceUpdateRequest', 'calcRatesDone', 'queueProcessingFinished',
           'buyNextOrder', 'sellNextOrder', 'getOracleDeficit'
           //'getBuyOrder(1)', 'getSellOrder(1)'
        ];

async function main() {
    contract = web3.eth.contract(JSON.parse(contractABI)).at(contractAddress); 
    web3.eth.defaultAccount = web3.eth.coinbase;
}

async function setFee(x) {
    var setFeesAddr = await contract.setFees(x, x);
    var setFeesMined = await web3.eth.getTransactionReceiptMined(setFeesAddr);
    logTransactionByReceipt(setFeesAddr);
    console.log("buyFee: " + contract.buyFee().toString(10));
    console.log("sellFee: " + contract.sellFee().toString(10));
    console.log("cryptoFiatRateBuy: " + contract.cryptoFiatRateBuy().toString(10));
    console.log("cryptoFiatRateSell: " + contract.cryptoFiatRateSell().toString(10));
}

async function testFee() {
    var fee = parseInt(prompt("buy and sell fees: ", "0"));
    console.log("buyFee: " + contract.buyFee().toString(10));
    console.log("sellFee: " + contract.sellFee().toString(10));
    console.log("cryptoFiatRateBuy: " + contract.cryptoFiatRateBuy().toString(10));
    console.log("cryptoFiatRateSell: " + contract.cryptoFiatRateSell().toString(10));
    await setFee(fee);
}

async function testFeesCascade() {
    console.log("buyFee: " + contract.buyFee().toString(10));
    console.log("sellFee: " + contract.sellFee().toString(10));
    console.log("cryptoFiatRateBuy: " + contract.cryptoFiatRateBuy().toString(10));
    console.log("cryptoFiatRateSell: " + contract.cryptoFiatRateSell().toString(10));
    await setFee(500);
    await setFee(7000);
    await setFee(1000);
    await setFee(6000);
    await setFee(2000);
    await setFee(5000);
    await setFee(4000);
    await setFee(3000);
    await setFee(500);
    await setFee(7000);
    await setFee(0);
    
    
}

async function testRequestUpdateRates() {
    var weiStr = prompt('send wei with requestUpdateRates ("." to send current deficit):', "0");
    var wei = (weiStr == ".") ? (await contract.getOracleDeficit.call()).toNumber() : parseInt(weiStr);
    console.log("Wei to send: ", wei);
    var acc1 = web3.eth.accounts[0];
    var requestUpdateRatesAddr = await contract.requestUpdateRates({from: acc1, value: wei, gas: 500000});
    var requestUpdateRatesMined = await web3.eth.getTransactionReceiptMined(requestUpdateRatesAddr);
    logTransactionByReceipt(requestUpdateRatesAddr);
}

async function testCalcRates() {
    var calcRatesAddr = await contract.calcRates({gas: 500000});
    var calcRatesMined = await web3.eth.getTransactionReceiptMined(calcRatesAddr);
    logTransactionByReceipt(calcRatesAddr);
}

async function testSetRelevancePeriod() {
    var period = parseInt(prompt("new relevance period: ", "0"));
    console.log(contract.relevancePeriod().toString(10));
    var setRelevancePeriodAddr = await contract.setRelevancePeriod(500);
    var setRelevancePeriodMined = await web3.eth.getTransactionReceiptMined(setRelevancePeriodAddr);
    logTransactionByReceipt(setRelevancePeriodAddr);
}

async function testBuyQueue() {
    var processBuyQueueAddr = await contract.processBuyQueue(0, {gas: 500000});
    await web3.eth.getTransactionReceiptMined(processBuyQueueAddr);
    logTransactionByReceipt(processBuyQueueAddr);
}

async function testAdd3BuyOrders() {
    console.log("Buy orders: ", contract.getBuyOrdersCount().toNumber());
    var addOrderAddr1 = await contract.createBuyOrder(web3.eth.defaultAccount, 0,
        {from: web3.eth.defaultAccount, value: web3.toWei(0.1, 'ether'), gas: 500000});
    var addOrderAddr2 = await contract.createBuyOrder(web3.eth.defaultAccount, 0,
        {from: web3.eth.defaultAccount, value: web3.toWei(0.2, 'ether'), gas: 500000});
    var addOrderAddr3 = await contract.createBuyOrder(web3.eth.defaultAccount, 0,
        {from: web3.eth.defaultAccount, value: web3.toWei(0.01, 'ether'), gas: 500000});
    await web3.eth.getTransactionReceiptMined(addOrderAddr1);
    await web3.eth.getTransactionReceiptMined(addOrderAddr2);
    await web3.eth.getTransactionReceiptMined(addOrderAddr3);
        logTransactionByReceipt(addOrderAddr3);
    console.log("Buy orders: ", contract.getBuyOrdersCount().toNumber());
    
}

main();