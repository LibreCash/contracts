async function main() {
    let  
        contract = web3.eth.contract(JSON.parse(contractABI)).at(contractAddress); 
    //let mainAccount = await web3.eth.getCoinbase(),
      //  mainAccBalance = await web3.eth.getBalance(mainAccount);
//    let token = await contract.methods.getToken().call();
        
//    console.log(`Основной аккаунт ${mainAccount}`);
//    console.log(`Баланс основного аккаунта ${mainAccBalance}`);
//    console.log(`token ${token}`);
    console.log(contract);
    web3.eth.defaultAccount = web3.eth.coinbase;
    var updateRatesTx = await contract.requestUpdateRates();
    console.log(updateRatesTx);

}

main();