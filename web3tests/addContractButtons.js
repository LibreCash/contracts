var divContractList = document.getElementById("contractList");
if (contracts) {
    contracts.forEach(function(contractName) {
        let buttonContract = document.createElement('button');
        buttonContract.classList.add("buttonContract");
        buttonContract.innerText = contractName;
        divContractList.appendChild(buttonContract);
        buttonContract.onclick = setContract;
    });
}
function setContract(e) {
    let contractName = e.target.innerText;
    let textContractData = document.getElementById("inputContractData");
    textContractData.value = "data/" + e.target.innerText + ".js";
}