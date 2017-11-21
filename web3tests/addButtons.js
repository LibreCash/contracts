var divContractList = document.getElementById("contractList");
var divTestList = document.getElementById("testList");
var btnTestRun = document.getElementById("testRunButton");
if (contracts) {
    contracts.forEach(function(contractName) {
        let buttonContract = document.createElement('button');
        buttonContract.classList.add("buttonContract");
        buttonContract.classList.add("btn");
        buttonContract.classList.add("btn-primary");
        buttonContract.innerText = contractName;
        divContractList.appendChild(buttonContract);
        buttonContract.onclick = setContract;
    });
}
if (tests) {
    tests.forEach(function(testName) {
        let buttonTest = document.createElement('button');
        buttonTest.classList.add("buttonTest");
        buttonTest.classList.add("btn");
        buttonTest.classList.add("btn-primary");
        buttonTest.innerText = testName;
        divTestList.appendChild(buttonTest);
        buttonTest.onclick = setTest;
    });
}
btnTestRun.style.display = "block";

function setContract(e) {
    let contractName = e.target.innerText;
    let textContractData = document.getElementById("inputContractData");
    textContractData.value = "../build/data/" + e.target.innerText + ".js";
}

function setTest(e) {
    let contractName = e.target.innerText;
    let textContractData = document.getElementById("inputTestData");
    textContractData.value = "tests/" + e.target.innerText;
}