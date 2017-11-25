const Web3 = require("web3");
var web3 = new Web3("http://localhost:8545");
var networkType;
web3.eth.net.getNetworkType().then((type)=>{console.log(type)});
