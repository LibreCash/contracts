var allTestFunctions = [];
for(var i in this) {
	if(((typeof this[i]).toString() == "function") && (this[i].toString().indexOf("native") == -1)) {
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
    buttonTestFunction.classList.add("btn-success");
    buttonTestFunction.innerText = testFunction;
    divFunctionList.appendChild(buttonTestFunction);
    buttonTestFunction.onclick = window[testFunction];
});

var divWatches = document.getElementById("watches");
var allTimers = [];
monitor.forEach(function(variable) {
    let divWatch = document.createElement("div");
    divWatches.appendChild(divWatch);
    allTimers.push(setInterval(
        function() {
            divWatch.innerText = variable + ": " + contract[variable]().toString(10);
        }, 100
    ));
    //console.log(contract[variable]().toString(10));
});