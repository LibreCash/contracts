/*alert(contractName);
alert(contractAddress);
alert(contractABI);
*/
const 
    Web3 = require('web3');

    console.log(Web3.providers);
var 
   // web3 = new Web3(new Web3.providers.WebsocketProvider("ws://localhost:8545")),
    web3 = new Web3("ws://localhost:8545"),
    contract = web3.eth.contract(JSON.parse(contractABI), contractAddress);

async function main() {
    let  
        mainAccount = await web3.eth.getCoinbase(),
        mainAccBalance = await web3.eth.getBalance(mainAccount);
    let token = await contract.methods.getToken().call();
        
    console.log(`Основной аккаунт ${mainAccount}`);
    console.log(`Баланс основного аккаунта ${mainAccBalance}`);
    console.log(`token ${token}`);
    


}

main();