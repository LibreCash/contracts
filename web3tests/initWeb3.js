initWeb3();

function initWeb3(){
    if (typeof web3 !== 'undefined') {
        web3 = new Web3(web3.currentProvider);
        $('#web3-status').text("Using existed web3");
    } else {
    // set the provider you want from Web3.providers
        web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
        $('#web3-status').text("New web3 instanse created");
    }
}