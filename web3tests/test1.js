async function main() {  
        contract = web3.eth.contract(JSON.parse(contractABI)).at(contractAddress); 
    //let mainAccount = await web3.eth.getCoinbase(),
      //  mainAccBalance = await web3.eth.getBalance(mainAccount);
//    let token = await contract.methods.getToken().call();
        
//    console.log(`Основной аккаунт ${mainAccount}`);
//    console.log(`Баланс основного аккаунта ${mainAccBalance}`);
//    console.log(`token ${token}`);
    console.log(contract);
    web3.eth.defaultAccount = web3.eth.coinbase;
    var buyFee = await contract.buyFee.call();
    console.log(buyFee.toNumber());
    var setBuyFeeTX = await contract.setBuyFee(300);
    var x = await web3.eth.getTransactionReceiptMined(setBuyFeeTX, 500);
    console.log(x);
    console.log(web3.eth.getTransaction(setBuyFeeTX));
    console.log(web3.eth.getTransactionReceipt(setBuyFeeTX));
    var buyFee = await contract.buyFee.call();
    console.log(buyFee.toNumber());
 /*   var updateRatesTx = await contract.requestUpdateRates();
    console.log(web3.eth.getTransaction(updateRatesTx));
    var numWaitingOracles = await contract.numWaitingOracles.call();
    console.log(numWaitingOracles.toString(10));*/

}

main();