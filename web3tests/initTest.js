var allTestFunctions = [];
for (var i in this) {
	if (((typeof this[i]).toString() == "function") && (this[i].toString().indexOf("native") == -1)) {
        if (this[i].name.substr(0, 4) == "test") {
            allTestFunctions.push(this[i].name);
        }
	}
}
var divFunctionList = document.getElementById("functionList");
allTestFunctions.forEach(function(testFunction) {
    let buttonTestFunction = document.createElement('button');
    buttonTestFunction.classList.add("buttonTestFunction");
    buttonTestFunction.classList.add("btn");
    buttonTestFunction.classList.add("btn-basic");
    buttonTestFunction.innerText = testFunction;
    divFunctionList.appendChild(buttonTestFunction);
    buttonTestFunction.onclick = function() {
        console.log('START ' + testFunction);
        buttonTestFunction.classList.remove('btn-basic');
        buttonTestFunction.classList.add('btn-warning');
        window[testFunction].apply(null); // асинхронный же метод, решить как ждать
        buttonTestFunction.classList.remove('btn-warning');
        buttonTestFunction.classList.add('btn-success');
    }
});

var divWatches = document.getElementById("watches");
var allTimers = [];
monitor.forEach(function(variable) {
    let divWatch = document.createElement("div");
    divWatches.appendChild(divWatch);
    allTimers.push(setInterval(
        function() {
            divWatch.innerText = variable + ": " + contract[variable]().toString(10);
        }, 500
    ));
    //console.log(contract[variable]().toString(10));
});

// сырое
web3.eth.filter({
    address: contract.address,
    from: 1,
    to: 'latest'
}).get(function (err, result) {
    console.log(result);
});